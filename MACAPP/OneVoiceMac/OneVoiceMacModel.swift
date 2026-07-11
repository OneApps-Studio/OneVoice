import AppKit
import AVFoundation
import Foundation
import Observation
import OneVoiceAppleSpeech
import OneVoiceCloudSync
import OneVoiceCore
import OneVoiceQwenSpeech
import ServiceManagement

@MainActor
@Observable
final class OneVoiceMacModel {
    static let shared = OneVoiceMacModel()

    enum SetupIssue: String, Identifiable {
        case accessibility
        case inputMonitoring
        case microphone
        case speechRecognition

        var id: String { rawValue }

        var title: String {
            switch self {
            case .accessibility: "Accessibility"
            case .inputMonitoring: "Input Monitoring"
            case .microphone: "Microphone"
            case .speechRecognition: "Speech Recognition"
            }
        }

        var detail: String {
            switch self {
            case .accessibility: "Required to insert the transcript into the focused text field."
            case .inputMonitoring: "Required to detect Fn and Right Command in any app."
            case .microphone: "Required to capture your voice."
            case .speechRecognition: "Required to transcribe speech locally."
            }
        }
    }

    private(set) var isReady = false
    private(set) var isStarting = false
    private(set) var isRecording = false
    private(set) var isFinishing = false
    private(set) var isImportingMedia = false
    private(set) var mediaImportProgress = 0.0
    private(set) var mediaImportFileName = ""
    private(set) var latestImportedEntry: VoiceEntry?
    private(set) var permissionGeneration = 0
    private(set) var launchAtLoginEnabled = false
    private(set) var history: [VoiceEntry] = []
    private(set) var audioURLs: [UUID: URL] = [:]
    private(set) var playingEntryID: UUID?
    private(set) var replacements: [DictionaryReplacement] = []
    private(set) var qwenInstalled = false
    private(set) var qwenIsDownloading = false
    private(set) var qwenDownloadProgress = 0.0
    private(set) var qwenStatusText = "Not installed"
    private(set) var iCloudSyncStatus: OneVoiceCloudSyncStatus = .disabled
    var liveTranscript: String { session?.partialTranscript ?? "" }
    var lastError: String?
    var lastDeliveryMessage: String?
    var localeIdentifier: String {
        didSet { UserDefaults.standard.set(localeIdentifier, forKey: "recognitionLocale") }
    }
    var appLanguage: MacAppLanguage {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: MacAppLanguage.defaultsKey) }
    }
    var pushToTalkKey: GlobalHotkeyKey {
        didSet {
            if pushToTalkKey == toggleKey {
                toggleKey = .fallback(excluding: pushToTalkKey, preferred: .defaultToggle)
            }
            UserDefaults.standard.set(pushToTalkKey.rawValue, forKey: "pushToTalkKey")
            reinstallHotkeys()
        }
    }
    var toggleKey: GlobalHotkeyKey {
        didSet {
            if toggleKey == pushToTalkKey {
                pushToTalkKey = .fallback(excluding: toggleKey, preferred: .defaultPushToTalk)
            }
            UserDefaults.standard.set(toggleKey.rawValue, forKey: "toggleKey")
            reinstallHotkeys()
        }
    }
    var useQwenFinalPass: Bool {
        didSet {
            UserDefaults.standard.set(useQwenFinalPass, forKey: "useQwenFinalPass")
            Task { await speechEngine.setUseQwenFinalPass(useQwenFinalPass) }
        }
    }
    var iCloudSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled") }
    }

    private let qwenManager: QwenModelManager
    private let speechEngine: HybridTranscriptionEngine
    private let insertion = MacTextInsertion()
    private let microphone = MacMicrophoneCapture()
    private let mediaReader = MediaAudioReader()
    private let overlay = DictationOverlayController()
    private var store: VoiceEntryStore?
    private var recordingStore: VoiceRecordingStore?
    private var dictionaryStore: DictionaryReplacementStore?
    private var cloudSync: OneVoiceCloudSync?
    private var session: DictationSession?
    private var hotkeyMonitor: GlobalHotkeyMonitor?
    private var startedAt: ContinuousClock.Instant?
    private var didLaunch = false
    private var hotkeyStartTask: Task<Void, Never>?
    private var mediaImportTask: Task<Void, Never>?
    private var pushToTalkIsHeld = false
    private var audioPlayer: AVAudioPlayer?
    private var playbackTask: Task<Void, Never>?
    #if DEBUG
    private var debugHotkeyOutputURL: URL?
    #endif

    private init() {
        let qwenManager = QwenModelManager(cacheDirectory: OneVoiceMacIdentity.qwenModelDirectory)
        let qwenEnabled = UserDefaults.standard.object(forKey: "useQwenFinalPass") as? Bool ?? true
        appLanguage = MacAppLanguage(
            rawValue: UserDefaults.standard.string(forKey: MacAppLanguage.defaultsKey) ?? ""
        ) ?? .system
        let storedPushToTalkKey = GlobalHotkeyKey(
            rawValue: UserDefaults.standard.string(forKey: "pushToTalkKey") ?? ""
        ) ?? .defaultPushToTalk
        pushToTalkKey = storedPushToTalkKey
        let storedToggleKey = GlobalHotkeyKey(
            rawValue: UserDefaults.standard.string(forKey: "toggleKey") ?? ""
        ) ?? .defaultToggle
        toggleKey = storedToggleKey == storedPushToTalkKey
            ? .fallback(excluding: storedPushToTalkKey, preferred: .defaultToggle)
            : storedToggleKey
        localeIdentifier = UserDefaults.standard.string(forKey: "recognitionLocale") ?? "zh-Hans"
        self.qwenManager = qwenManager
        speechEngine = HybridTranscriptionEngine(
            liveEngine: AppleSpeechTranscriptionEngine(),
            qwenManager: qwenManager,
            useQwenFinalPass: qwenEnabled
        )
        useQwenFinalPass = qwenEnabled
        iCloudSyncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    var missingPermissions: [SetupIssue] {
        var result: [SetupIssue] = []
        if !MacPermissions.hasAccessibility { result.append(.accessibility) }
        if !MacPermissions.hasInputMonitoring { result.append(.inputMonitoring) }
        if !MacPermissions.hasMicrophone { result.append(.microphone) }
        if !MacPermissions.hasSpeechRecognition { result.append(.speechRecognition) }
        return result
    }

    func launch() async {
        guard !didLaunch else { return }
        didLaunch = true
        do {
            let support = try applicationSupportDirectory()
            let store = try await VoiceEntryStore(fileURL: support.appending(path: "history.json"))
            let recordingStore = VoiceRecordingStore(
                directoryURL: support.appending(path: "Recordings", directoryHint: .isDirectory)
            )
            let dictionaryStore = try await DictionaryReplacementStore(
                fileURL: support.appending(path: "dictionary.json")
            )
            self.store = store
            self.recordingStore = recordingStore
            self.dictionaryStore = dictionaryStore
            replacements = await dictionaryStore.all()
            qwenInstalled = await qwenManager.isInstalled()
            qwenStatusText = qwenInstalled ? "Installed" : "Not installed"
            session = DictationSession(
                engine: speechEngine,
                insertion: insertion,
                store: store,
                normalizer: TranscriptNormalizer(replacements: replacements)
            )
            await refreshHistory()
            #if DEBUG
            configureHotkeyProbeIfRequested()
            #endif
            installHotkeys()
            isReady = true
            if iCloudSyncEnabled {
                Task { [weak self] in
                    await self?.startCloudSync(
                        supportDirectory: support,
                        store: store,
                        dictionaryStore: dictionaryStore
                    )
                }
            }
            #if DEBUG
            await runSpeechFixtureIfRequested()
            await runQwenFixtureIfRequested()
            await runInsertionProbeIfRequested()
            await runPermissionProbeIfRequested()
            await runMicrophoneProbeIfRequested()
            #endif
        } catch {
            lastError = error.localizedDescription
        }
    }

    func requestSystemPermissions() async {
        _ = await MacPermissions.requestMicrophone()
        _ = await MacPermissions.requestSpeechRecognition()
        MacPermissions.requestAccessibility()
        MacPermissions.requestInputMonitoring()
        try? await Task.sleep(for: .milliseconds(400))
        permissionGeneration += 1
        installHotkeys()
    }

    func refreshPermissionStatus() {
        permissionGeneration += 1
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        installHotkeys()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            lastError = error.localizedDescription
        }
    }

    func handleHotkey(_ action: HotkeyGestureInterpreter.Action) {
        #if DEBUG
        if let debugHotkeyOutputURL {
            let previous = (try? String(contentsOf: debugHotkeyOutputURL, encoding: .utf8)) ?? ""
            try? (previous + String(describing: action) + "\n").write(
                to: debugHotkeyOutputURL,
                atomically: true,
                encoding: .utf8
            )
            return
        }
        #endif
        switch action {
        case .armCapture:
            break
        case .beginPushToTalk:
            pushToTalkIsHeld = true
            beginHotkeyDictation(pushToTalk: true)
        case .finishRecording:
            pushToTalkIsHeld = false
            if isStarting {
                hotkeyStartTask?.cancel()
            } else {
                Task { await finishDictation() }
            }
        case .cancelCapture:
            pushToTalkIsHeld = false
            break
        case .toggleRecording:
            if isStarting {
                hotkeyStartTask?.cancel()
            } else if isRecording {
                Task { await finishDictation() }
            } else {
                beginHotkeyDictation(pushToTalk: false)
            }
        }
    }

    func toggleDictation() {
        if isStarting {
            hotkeyStartTask?.cancel()
        } else if isRecording {
            Task { await finishDictation() }
        } else if !isFinishing {
            beginHotkeyDictation(pushToTalk: false)
        }
    }

    func startDictation() async {
        guard isReady, !isStarting, !isRecording, !isFinishing, !isImportingMedia, let session else { return }
        isStarting = true
        defer { isStarting = false }
        lastError = nil
        lastDeliveryMessage = nil

        do {
            guard await MacPermissions.requestMicrophone() else {
                lastError = "Microphone access is required. Enable \(OneVoiceMacIdentity.displayName) in System Settings → Privacy & Security → Microphone."
                return
            }
            try Task.checkCancellation()
            guard await MacPermissions.requestSpeechRecognition() else {
                lastError = "Speech Recognition access is required. Enable \(OneVoiceMacIdentity.displayName) in System Settings → Privacy & Security → Speech Recognition."
                return
            }
            try Task.checkCancellation()
            try await session.begin(localeIdentifier: localeIdentifier, source: .quickDictation)
            try Task.checkCancellation()
            try microphone.start(
                frameHandler: { [weak self] frame in
                    Task { @MainActor [weak self] in
                        guard let self, self.isRecording else { return }
                        do {
                            try await self.session?.append(frame)
                        } catch {
                            await self.failRecording(error)
                        }
                    }
                },
                errorHandler: { [weak self] error in
                    Task { @MainActor [weak self] in
                        guard let self, self.isRecording else { return }
                        await self.failRecording(error)
                    }
                }
            )
            startedAt = .now
            isRecording = true
            overlay.show(model: self)
        } catch is CancellationError {
            microphone.stop()
            await session.cancel()
            overlay.hide()
        } catch {
            microphone.stop()
            await session.cancel()
            lastError = error.localizedDescription
            overlay.hide()
        }
    }

    func finishDictation() async {
        guard isRecording, let session else { return }
        isRecording = false
        isFinishing = true
        microphone.stop()
        let duration = startedAt.map { $0.duration(to: .now).timeInterval } ?? 0

        do {
            let entry = try await session.finish(duration: duration)
            await cloudSync?.save(entry)
            lastDeliveryMessage = deliveryMessage(for: session.lastInsertionOutcome)
            await refreshHistory()
        } catch {
            lastError = error.localizedDescription
        }
        isFinishing = false
        startedAt = nil
        overlay.hide()
        session.reset()
    }

    func cancelDictation() async {
        hotkeyStartTask?.cancel()
        microphone.stop()
        await session?.cancel()
        isRecording = false
        isFinishing = false
        startedAt = nil
        overlay.hide()
    }

    func importMedia(at url: URL) {
        guard mediaImportTask == nil, !isRecording, !isStarting, !isFinishing else { return }
        mediaImportTask = Task { [weak self] in
            guard let self else { return }
            await self.runMediaImport(at: url)
            self.mediaImportTask = nil
        }
    }

    func cancelMediaImport() {
        mediaImportTask?.cancel()
    }

    private func runMediaImport(at url: URL) async {
        guard isReady, let session else { return }
        isImportingMedia = true
        mediaImportProgress = 0
        mediaImportFileName = url.lastPathComponent
        latestImportedEntry = nil
        lastError = nil
        lastDeliveryMessage = nil
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
            isImportingMedia = false
            mediaImportProgress = 0
            mediaImportFileName = ""
        }

        do {
            guard await MacPermissions.requestSpeechRecognition() else {
                throw NSError(
                    domain: "OneVoiceMediaImport",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Speech Recognition access is required to transcribe this file."]
                )
            }
            try await session.begin(localeIdentifier: localeIdentifier, source: .importedFile)
            let duration = try await mediaReader.read(url: url) { frame in
                try await session.append(frame)
            } onProgress: { [weak self] progress in
                await MainActor.run { self?.mediaImportProgress = progress }
            }
            latestImportedEntry = try await session.finish(duration: duration)
            if let latestImportedEntry { await cloudSync?.save(latestImportedEntry) }
            await refreshHistory()
            lastDeliveryMessage = "Transcribed \(url.lastPathComponent) and saved it to History."
            session.reset()
        } catch is CancellationError {
            await session.cancel()
            lastDeliveryMessage = "File transcription cancelled."
        } catch {
            await session.cancel()
            lastError = error.localizedDescription
        }
    }

    func refreshHistory(query: String = "") async {
        history = await store?.entries(matching: query) ?? []
        guard let recordingStore else {
            audioURLs = [:]
            return
        }
        var urls: [UUID: URL] = [:]
        for entry in history {
            if let url = await recordingStore.fileURL(for: entry) {
                urls[entry.id] = url
            }
        }
        audioURLs = urls
    }

    func deleteHistory(_ entries: [VoiceEntry]) async {
        guard let store else { return }
        do {
            for entry in entries {
                if playingEntryID == entry.id { stopPlayback() }
                try await recordingStore?.deleteRecording(for: entry)
                try await store.delete(id: entry.id)
                await cloudSync?.deleteEntry(id: entry.id)
            }
            await refreshHistory()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func saveReplacement(spoken: String, written: String) async {
        let spoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let written = written.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty, !written.isEmpty, let dictionaryStore else { return }
        do {
            let replacement = DictionaryReplacement(spoken: spoken, written: written)
            try await dictionaryStore.save(replacement)
            await cloudSync?.save(replacement)
            replacements = await dictionaryStore.all()
            rebuildSession()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteReplacement(_ replacement: DictionaryReplacement) async {
        guard let dictionaryStore else { return }
        do {
            try await dictionaryStore.delete(id: replacement.id)
            await cloudSync?.deleteReplacement(id: replacement.id)
            replacements = await dictionaryStore.all()
            rebuildSession()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func downloadQwenModel() async {
        guard !qwenIsDownloading else { return }
        qwenIsDownloading = true
        qwenDownloadProgress = 0
        qwenStatusText = "Preparing download…"
        lastError = nil
        do {
            try await qwenManager.download { [weak self] progress, status in
                Task { @MainActor [weak self] in
                    self?.qwenDownloadProgress = progress
                    self?.qwenStatusText = status
                }
            }
            qwenInstalled = true
            qwenDownloadProgress = 1
            qwenStatusText = "Installed and ready"
            useQwenFinalPass = true
        } catch {
            qwenInstalled = await qwenManager.isInstalled()
            qwenStatusText = qwenInstalled ? "Installed" : "Download failed"
            lastError = error.localizedDescription
        }
        qwenIsDownloading = false
    }

    func removeQwenModel() async {
        guard !isRecording, !qwenIsDownloading else { return }
        do {
            try await qwenManager.removeDownloadedModel()
            qwenInstalled = false
            qwenDownloadProgress = 0
            qwenStatusText = "Not installed"
            useQwenFinalPass = false
        } catch {
            lastError = error.localizedDescription
        }
    }

    func copyTranscript(_ entry: VoiceEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.transcript, forType: .string)
    }

    func audioURL(for entry: VoiceEntry) -> URL? {
        audioURLs[entry.id]
    }

    func togglePlayback(_ entry: VoiceEntry) async {
        if playingEntryID == entry.id {
            stopPlayback()
            return
        }
        let url: URL?
        if let cachedURL = audioURLs[entry.id] {
            url = cachedURL
        } else {
            url = await recordingStore?.fileURL(for: entry)
        }
        guard let url else {
            lastError = "The recording audio is not available on this Mac yet. Try Sync Now after iCloud finishes."
            return
        }
        do {
            stopPlayback()
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            guard player.play() else {
                throw NSError(
                    domain: "OneVoicePlayback",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "The recording could not start playing."]
                )
            }
            audioPlayer = player
            playingEntryID = entry.id
            let playbackID = entry.id
            playbackTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(player.duration + 0.2))
                guard !Task.isCancelled, self?.playingEntryID == playbackID else { return }
                self?.stopPlayback()
            }
        } catch {
            stopPlayback()
            lastError = error.localizedDescription
        }
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        playingEntryID = nil
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        iCloudSyncEnabled = enabled
        Task { [weak self] in
            guard let self else { return }
            if enabled,
               let store = self.store,
               let dictionaryStore = self.dictionaryStore,
               let support = try? self.applicationSupportDirectory() {
                await self.startCloudSync(
                    supportDirectory: support,
                    store: store,
                    dictionaryStore: dictionaryStore
                )
            } else {
                await self.cloudSync?.stop()
                self.cloudSync = nil
                self.iCloudSyncStatus = .disabled
            }
        }
    }

    func refreshCloudSync() {
        Task { await cloudSync?.refresh() }
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") else { return }
        NSWorkspace.shared.open(url)
    }

    private func installHotkeys() {
        guard MacPermissions.hasInputMonitoring else { return }
        if hotkeyMonitor == nil {
            hotkeyMonitor = GlobalHotkeyMonitor(
                pushToTalkKey: pushToTalkKey,
                toggleKey: toggleKey
            ) { [weak self] action in
                self?.handleHotkey(action)
            }
        }
        if hotkeyMonitor?.start() == false {
            lastError = "Input Monitoring permission is required before global shortcuts can start."
        }
    }

    private func reinstallHotkeys() {
        guard didLaunch else { return }
        hotkeyMonitor?.stop()
        hotkeyMonitor = nil
        installHotkeys()
    }

    private func beginHotkeyDictation(pushToTalk: Bool) {
        guard hotkeyStartTask == nil, !isRecording, !isFinishing else { return }
        hotkeyStartTask = Task { [weak self] in
            guard let self else { return }
            await self.startDictation()
            if pushToTalk, !self.pushToTalkIsHeld, self.isRecording {
                await self.finishDictation()
            }
            self.hotkeyStartTask = nil
        }
    }

    private func deliveryMessage(for outcome: TextInsertionOutcome?) -> String {
        switch outcome {
        case .insertedDirectly:
            "Inserted into the focused field."
        case .pastedFromClipboard:
            "Pasted into the focused app. Your previous clipboard was restored."
        case .copiedToClipboard:
            "No editable field was available, so the transcript was copied."
        case .blockedSecureField:
            "Secure fields cannot be filled automatically. The transcript was copied."
        case .blockedUnverifiedTarget:
            "\(OneVoiceMacIdentity.displayName) could not verify that the focused field was safe to fill. The transcript was copied."
        case let .failed(message):
            "Automatic insertion failed: \(message)"
        case nil:
            "Transcript saved."
        }
    }

    private func rebuildSession() {
        guard let store, !isRecording else { return }
        session = DictationSession(
            engine: speechEngine,
            insertion: insertion,
            store: store,
            normalizer: TranscriptNormalizer(replacements: replacements)
        )
    }

    private func startCloudSync(
        supportDirectory: URL,
        store: VoiceEntryStore,
        dictionaryStore: DictionaryReplacementStore
    ) async {
        guard cloudSync == nil, let containerIdentifier = cloudContainerIdentifier else {
            if cloudContainerIdentifier == nil { iCloudSyncStatus = .unavailable }
            return
        }
        let sync = OneVoiceCloudSync(
            containerIdentifier: containerIdentifier,
            stateFileURL: supportDirectory.appending(path: "cloud-sync-state.json"),
            entryStore: store,
            replacementStore: dictionaryStore,
            recordingStore: recordingStore,
            statusHandler: { [weak self] status in
                await MainActor.run { self?.iCloudSyncStatus = status }
            },
            changeHandler: { [weak self] in
                await self?.reloadSyncedData()
            }
        )
        cloudSync = sync
        await sync.start()
    }

    private func reloadSyncedData() async {
        replacements = await dictionaryStore?.all() ?? []
        await refreshHistory()
        rebuildSession()
    }

    private var cloudContainerIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "OneVoiceCloudContainerIdentifier") as? String
    }

    private func failRecording(_ error: Error) async {
        lastError = error.localizedDescription
        await cancelDictation()
    }

    private func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(
            path: OneVoiceMacIdentity.applicationSupportDirectoryName,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    #if DEBUG
    private func runSpeechFixtureIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let fixtureIndex = arguments.firstIndex(of: "--onevoice-speech-fixture"),
              arguments.indices.contains(fixtureIndex + 1),
              let outputIndex = arguments.firstIndex(of: "--onevoice-speech-output"),
              arguments.indices.contains(outputIndex + 1) else {
            return
        }

        let fixtureURL = URL(fileURLWithPath: arguments[fixtureIndex + 1])
        let outputURL = URL(fileURLWithPath: arguments[outputIndex + 1])
        let statusURL = outputURL.appendingPathExtension("status")
        func mark(_ phase: String) {
            try? phase.write(to: statusURL, atomically: true, encoding: .utf8)
        }
        do {
            mark("requesting-permission")
            guard await MacPermissions.requestSpeechRecognition() else {
                throw NSError(
                    domain: "OneVoiceSpeechProbe",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Speech Recognition permission was denied."]
                )
            }
            mark("starting-engine")
            let engine = AppleSpeechTranscriptionEngine()
            let updates = try await engine.start(localeIdentifier: "en-US")
            mark("feeding-audio")
            let updateTask = Task {
                do {
                    for try await _ in updates {}
                } catch {}
            }
            let file = try AVAudioFile(forReading: fixtureURL)
            let format = file.processingFormat
            while file.framePosition < file.length {
                let count = min(1_024, AVAudioFrameCount(file.length - file.framePosition))
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else {
                    throw NSError(
                        domain: "OneVoiceSpeechProbe",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Could not allocate an audio buffer."]
                    )
                }
                try file.read(into: buffer, frameCount: count)
                guard let channels = buffer.floatChannelData else { continue }
                let frameCount = Int(buffer.frameLength)
                let channelCount = Int(format.channelCount)
                var samples = [Float](repeating: 0, count: frameCount)
                for channel in 0..<channelCount {
                    for index in 0..<frameCount {
                        samples[index] += channels[channel][index] / Float(channelCount)
                    }
                }
                try await engine.append(AudioFrame(samples: samples, sampleRate: format.sampleRate))
            }
            mark("finishing")
            let transcript = try await engine.finish().text
            _ = await updateTask.value
            try transcript.write(to: outputURL, atomically: true, encoding: .utf8)
            mark("complete")
        } catch {
            try? ("ERROR: " + error.localizedDescription).write(
                to: outputURL,
                atomically: true,
                encoding: .utf8
            )
            mark("failed: " + error.localizedDescription)
        }
    }

    private func runQwenFixtureIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let fixtureIndex = arguments.firstIndex(of: "--onevoice-qwen-fixture"),
              arguments.indices.contains(fixtureIndex + 1),
              let outputIndex = arguments.firstIndex(of: "--onevoice-qwen-output"),
              arguments.indices.contains(outputIndex + 1) else {
            return
        }

        let fixtureURL = URL(fileURLWithPath: arguments[fixtureIndex + 1])
        let outputURL = URL(fileURLWithPath: arguments[outputIndex + 1])
        let statusURL = outputURL.appendingPathExtension("status")
        func mark(_ phase: String) {
            try? phase.write(to: statusURL, atomically: true, encoding: .utf8)
        }

        do {
            if !(await qwenManager.isInstalled()) {
                mark("downloading")
                try await qwenManager.download { _, status in
                    try? status.write(to: statusURL, atomically: true, encoding: .utf8)
                }
            }

            mark("loading-audio")
            let file = try AVAudioFile(forReading: fixtureURL)
            let format = file.processingFormat
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                throw NSError(
                    domain: "OneVoiceQwenProbe",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not allocate an audio buffer."]
                )
            }
            try file.read(into: buffer)
            guard let channels = buffer.floatChannelData else {
                throw NSError(
                    domain: "OneVoiceQwenProbe",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Fixture must decode to floating-point PCM."]
                )
            }

            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(format.channelCount)
            var samples = [Float](repeating: 0, count: frameCount)
            for channel in 0..<channelCount {
                for index in 0..<frameCount {
                    samples[index] += channels[channel][index] / Float(channelCount)
                }
            }

            mark("transcribing")
            let transcript = try await qwenManager.transcribe(
                audio: samples,
                sampleRate: Int(format.sampleRate.rounded()),
                language: "English"
            )
            try transcript.write(to: outputURL, atomically: true, encoding: .utf8)
            mark("complete")
        } catch {
            try? ("ERROR: " + error.localizedDescription).write(
                to: outputURL,
                atomically: true,
                encoding: .utf8
            )
            mark("failed: " + error.localizedDescription)
        }
    }

    private func configureHotkeyProbeIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let outputIndex = arguments.firstIndex(of: "--onevoice-hotkey-output"),
              arguments.indices.contains(outputIndex + 1) else {
            return
        }
        let url = URL(fileURLWithPath: arguments[outputIndex + 1])
        try? "".write(to: url, atomically: true, encoding: .utf8)
        debugHotkeyOutputURL = url
    }

    private func runInsertionProbeIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let textIndex = arguments.firstIndex(of: "--onevoice-insertion-text"),
              arguments.indices.contains(textIndex + 1),
              let outputIndex = arguments.firstIndex(of: "--onevoice-insertion-output"),
              arguments.indices.contains(outputIndex + 1) else {
            return
        }

        let text = arguments[textIndex + 1]
        let outputURL = URL(fileURLWithPath: arguments[outputIndex + 1])
        try? await Task.sleep(for: .seconds(2))
        let target = insertion.captureTarget()
        let outcome = await insertion.insert(text, into: target)
        try? String(describing: outcome).write(
            to: outputURL,
            atomically: true,
            encoding: .utf8
        )
    }

    private func runPermissionProbeIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let outputIndex = arguments.firstIndex(of: "--onevoice-permissions-output"),
              arguments.indices.contains(outputIndex + 1) else {
            return
        }

        if arguments.contains("--onevoice-request-permissions") {
            await requestSystemPermissions()
        }
        let output = [
            "accessibility=\(MacPermissions.hasAccessibility)",
            "inputMonitoring=\(MacPermissions.hasInputMonitoring)",
            "microphone=\(MacPermissions.hasMicrophone)",
            "speechRecognition=\(MacPermissions.hasSpeechRecognition)",
        ].joined(separator: "\n")
        let outputURL = URL(fileURLWithPath: arguments[outputIndex + 1])
        try? output.write(to: outputURL, atomically: true, encoding: .utf8)
    }

    private func runMicrophoneProbeIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let outputIndex = arguments.firstIndex(of: "--onevoice-microphone-output"),
              arguments.indices.contains(outputIndex + 1) else {
            return
        }

        let outputURL = URL(fileURLWithPath: arguments[outputIndex + 1])
        guard await MacPermissions.requestMicrophone() else {
            try? "ERROR: Microphone permission is not granted.".write(
                to: outputURL,
                atomically: true,
                encoding: .utf8
            )
            return
        }

        let counter = MicrophoneProbeCounter()
        do {
            try microphone.start(
                frameHandler: { frame in counter.record(frame) },
                errorHandler: { error in counter.record(error) }
            )
            try await Task.sleep(for: .seconds(1))
            microphone.stop()
            let snapshot = counter.snapshot()
            let output = [
                "frames=\(snapshot.frames)",
                "samples=\(snapshot.samples)",
                "sampleRate=\(snapshot.sampleRate)",
                "error=\(snapshot.error ?? "none")",
            ].joined(separator: "\n")
            try output.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            microphone.stop()
            try? ("ERROR: " + error.localizedDescription).write(
                to: outputURL,
                atomically: true,
                encoding: .utf8
            )
        }
    }
    #endif
}

#if DEBUG
private final class MicrophoneProbeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var frames = 0
    private var samples = 0
    private var sampleRate = 0.0
    private var error: String?

    func record(_ frame: AudioFrame) {
        lock.withLock {
            frames += 1
            samples += frame.samples.count
            sampleRate = frame.sampleRate
        }
    }

    func record(_ error: Error) {
        lock.withLock { self.error = error.localizedDescription }
    }

    func snapshot() -> (frames: Int, samples: Int, sampleRate: Double, error: String?) {
        lock.withLock { (frames, samples, sampleRate, error) }
    }
}
#endif

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
