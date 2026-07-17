import AVFoundation
import Foundation
import Observation
import OneVoiceAppleSpeech
import OneVoiceCloudSync
import OneVoiceCore
import OneVoiceQwenSpeech
import Speech
import UIKit

@MainActor
@Observable
final class OneVoiceMobileModel {
    static let shared = OneVoiceMobileModel()

    private(set) var isReady = false
    private(set) var isStarting = false
    private(set) var isRecording = false
    private(set) var isFinishing = false
    private(set) var isImportingMedia = false
    private(set) var mediaImportProgress = 0.0
    private(set) var mediaImportFileName = ""
    private(set) var currentDuration: TimeInterval = 0
    private(set) var history: [VoiceEntry] = []
    private(set) var allHistory: [VoiceEntry] = []
    private(set) var audioURLs: [UUID: URL] = [:]
    private(set) var playingEntryID: UUID?
    private(set) var playbackTime: TimeInterval = 0
    private(set) var playbackDuration: TimeInterval = 0
    private(set) var playbackRate: Float = 1
    private(set) var replacements: [DictionaryReplacement] = []
    private(set) var latestEntry: VoiceEntry?
    private(set) var qwenInstalled = false
    private(set) var qwenIsDownloading = false
    private(set) var qwenDownloadProgress = 0.0
    private(set) var qwenStatusText = "Not installed"
    private(set) var iCloudSyncStatus: OneVoiceCloudSyncStatus = .disabled
    var lastError: String?
    var localeIdentifier: String {
        didSet { UserDefaults.standard.set(localeIdentifier, forKey: "onevoice.recognitionLocale") }
    }
    var useQwenFinalPass: Bool {
        didSet {
            UserDefaults.standard.set(useQwenFinalPass, forKey: "onevoice.useQwenFinalPass")
            Task { await speechEngine.setUseQwenFinalPass(useQwenFinalPass) }
        }
    }
    var iCloudSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(iCloudSyncEnabled, forKey: "onevoice.iCloudSyncEnabled") }
    }
    var liveTranscript: String { session?.partialTranscript ?? "" }
    var playbackIsActive: Bool { audioPlayer?.isPlaying == true }

    private let qwenManager: QwenModelManager
    private let speechEngine: HybridTranscriptionEngine
    private let microphone = MobileMicrophoneCapture()
    private let mediaReader = MediaAudioReader()
    private let insertion = MobileClipboardInsertion()
    private var store: VoiceEntryStore?
    private var recordingStore: VoiceRecordingStore?
    private var dictionaryStore: DictionaryReplacementStore?
    private var cloudSync: OneVoiceCloudSync?
    private var session: DictationSession?
    private var startedAt: ContinuousClock.Instant?
    private var durationTask: Task<Void, Never>?
    private var mediaImportTask: Task<Void, Never>?
    private var didLaunch = false
    private var recordingAttempt = 0
    private var activeRecordingID: UUID?
    private var activeRecordingURL: URL?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTask: Task<Void, Never>?
    private var historyQuery = ""

    private init() {
        let qwenManager = QwenModelManager(cacheDirectory: Self.qwenModelDirectory)
        let qwenEnabled = UserDefaults.standard.object(forKey: "onevoice.useQwenFinalPass") as? Bool ?? true
        let liveEngine: any TranscriptionEngine
        #if DEBUG
        if ProcessInfo.processInfo.environment["ONEVOICE_UI_TEST_FAKE_SPEECH"] == "1" {
            liveEngine = UITestTranscriptionEngine()
        } else {
            liveEngine = AppleSpeechTranscriptionEngine()
        }
        #else
        liveEngine = AppleSpeechTranscriptionEngine()
        #endif
        self.qwenManager = qwenManager
        speechEngine = HybridTranscriptionEngine(
            liveEngine: liveEngine,
            qwenManager: qwenManager,
            useQwenFinalPass: qwenEnabled
        )
        useQwenFinalPass = qwenEnabled
        iCloudSyncEnabled = UserDefaults.standard.object(forKey: "onevoice.iCloudSyncEnabled") as? Bool ?? true
        localeIdentifier = UserDefaults.standard.string(forKey: "onevoice.recognitionLocale") ?? "zh-Hans"
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
            session = makeSession(store: store)
            await recoverPendingRecordings(store: store, recordingStore: recordingStore)
            await refreshHistory()
            latestEntry = history.first
            isReady = true
            var shouldStartCloudSync = iCloudSyncEnabled
            #if DEBUG
            if ProcessInfo.processInfo.environment["ONEVOICE_UI_TEST_SYNCED"] == "1" {
                iCloudSyncStatus = .synced
                shouldStartCloudSync = false
            }
            #endif
            if shouldStartCloudSync {
                Task { [weak self] in
                    await self?.startCloudSync(
                        supportDirectory: support,
                        store: store,
                        dictionaryStore: dictionaryStore
                    )
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func startRecording() async {
        guard isReady, !isStarting, !isRecording, !isFinishing, !isImportingMedia, let session else { return }
        recordingAttempt += 1
        let attempt = recordingAttempt
        isStarting = true
        defer { isStarting = false }
        lastError = nil
        guard await requestMicrophone() else { return }
        guard attempt == recordingAttempt else { return }
        guard await requestSpeech() else { return }
        guard attempt == recordingAttempt else { return }

        do {
            stopPlayback()
            let recordingID = UUID()
            guard let recordingStore else { return }
            let recordingURL = try await recordingStore.pendingRecordingURL(id: recordingID)
            activeRecordingID = recordingID
            activeRecordingURL = recordingURL
            try await session.begin(localeIdentifier: localeIdentifier, source: .voiceNote)
            guard attempt == recordingAttempt else {
                await session.cancel()
                return
            }
            try microphone.start(
                recordingURL: recordingURL,
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
            currentDuration = 0
            isRecording = true
            durationTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let self, let startedAt = self.startedAt else { return }
                    self.currentDuration = startedAt.duration(to: .now).timeInterval
                }
            }
        } catch is CancellationError {
            microphone.stop()
            await session.cancel()
            await recordingStore?.removeTemporaryRecording(at: activeRecordingURL)
            activeRecordingID = nil
            activeRecordingURL = nil
        } catch {
            microphone.stop()
            await session.cancel()
            await recordingStore?.removeTemporaryRecording(at: activeRecordingURL)
            activeRecordingID = nil
            activeRecordingURL = nil
            lastError = error.localizedDescription
        }
    }

    func finishRecording() async {
        guard isRecording,
              let session,
              let recordingStore,
              let recordingID = activeRecordingID,
              let recordingURL = activeRecordingURL else { return }
        isRecording = false
        isFinishing = true
        durationTask?.cancel()
        durationTask = nil
        microphone.stop()
        let finalDuration: TimeInterval
        do {
            finalDuration = try validatedAudioDuration(at: recordingURL)
        } catch {
            lastError = "The recording is safe in the recovery folder, but OneVoice could not finalize it yet: \(error.localizedDescription)"
            isFinishing = false
            startedAt = nil
            activeRecordingID = nil
            activeRecordingURL = nil
            await session.cancel()
            return
        }
        currentDuration = finalDuration
        var committedRecording: VoiceRecordingFile?
        do {
            let recording = try await recordingStore.commitRecording(
                from: recordingURL,
                id: recordingID
            )
            committedRecording = recording
            var entry = try await session.finish(
                duration: finalDuration,
                id: recordingID,
                audioFileName: recording.fileName,
                audioByteCount: recording.byteCount
            )
            entry.title = suggestedTitle(for: entry.transcript)
            try await store?.save(entry)
            latestEntry = entry
            Task { [cloudSync] in await cloudSync?.save(entry) }
            await refreshHistory()
        } catch {
            if let committedRecording, let store {
                do {
                    let entry = VoiceEntry(
                        id: recordingID,
                        rawTranscript: "",
                        transcript: "",
                        duration: finalDuration,
                        localeIdentifier: localeIdentifier,
                        engineIdentifier: "transcription-unavailable",
                        source: .voiceNote,
                        title: fallbackRecordingTitle(),
                        audioFileName: committedRecording.fileName,
                        audioByteCount: committedRecording.byteCount
                    )
                    try await store.save(entry)
                    latestEntry = entry
                    Task { [cloudSync] in await cloudSync?.save(entry) }
                    await refreshHistory()
                    lastError = "The recording was saved, but automatic transcription failed: \(error.localizedDescription)"
                } catch {
                    lastError = "The recording could not be added to the library: \(error.localizedDescription)"
                }
            } else {
                lastError = error.localizedDescription
            }
        }
        isFinishing = false
        startedAt = nil
        activeRecordingID = nil
        activeRecordingURL = nil
        session.reset()
    }

    private func recoverPendingRecordings(
        store: VoiceEntryStore,
        recordingStore: VoiceRecordingStore
    ) async {
        let candidates: [(id: UUID, fileURL: URL, byteCount: Int64, needsCommit: Bool)]
        do {
            let pending = try await recordingStore.pendingRecordings().map {
                (id: $0.id, fileURL: $0.fileURL, byteCount: $0.byteCount, needsCommit: true)
            }
            let referencedIDs = Set(await store.entries().map(\.id))
            let unindexed = try await recordingStore
                .unindexedRecordings(referencedEntryIDs: referencedIDs)
                .map {
                    (
                        id: $0.id,
                        fileURL: $0.file.fileURL,
                        byteCount: $0.file.byteCount,
                        needsCommit: false
                    )
                }
            candidates = pending + unindexed
        } catch {
            lastError = "OneVoice could not inspect recordings awaiting recovery: \(error.localizedDescription)"
            return
        }
        guard !candidates.isEmpty else { return }

        var recoveryMessages: [String] = []
        var recoveredIDs: Set<UUID> = []
        for candidate in candidates where !recoveredIDs.contains(candidate.id) {
            do {
                guard candidate.byteCount > 0 else {
                    throw NSError(
                        domain: "OneVoiceRecordingRecovery",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "The pending recording is empty."]
                    )
                }
                let duration = try validatedAudioDuration(at: candidate.fileURL)
                let recording: VoiceRecordingFile
                if candidate.needsCommit {
                    recording = try await recordingStore.commitRecording(
                        from: candidate.fileURL,
                        id: candidate.id
                    )
                } else {
                    recording = VoiceRecordingFile(
                        fileName: candidate.fileURL.lastPathComponent,
                        fileURL: candidate.fileURL,
                        byteCount: candidate.byteCount
                    )
                }
                let fallback = VoiceEntry(
                    id: candidate.id,
                    rawTranscript: "",
                    transcript: "",
                    duration: duration,
                    localeIdentifier: localeIdentifier,
                    engineIdentifier: "recovered-audio",
                    source: .voiceNote,
                    title: fallbackRecordingTitle(),
                    audioFileName: recording.fileName,
                    audioByteCount: recording.byteCount
                )
                try await store.save(fallback)
                recoveredIDs.insert(candidate.id)

                let recoverySession = makeSession(store: store)
                do {
                    try await recoverySession.begin(localeIdentifier: localeIdentifier, source: .voiceNote)
                    _ = try await mediaReader.read(url: recording.fileURL) { frame in
                        try await recoverySession.append(frame)
                    } onProgress: { _ in }
                    var recovered = try await recoverySession.finish(
                        duration: duration,
                        id: candidate.id,
                        audioFileName: recording.fileName,
                        audioByteCount: recording.byteCount
                    )
                    recovered.title = suggestedTitle(for: recovered.transcript)
                    try await store.save(recovered)
                    recoverySession.reset()
                } catch {
                    await recoverySession.cancel()
                    recoveryMessages.append("Audio recovered; transcription will need another try.")
                }
            } catch {
                recoveryMessages.append("A recording remains in safe recovery storage: \(error.localizedDescription)")
            }
        }
        if !recoveryMessages.isEmpty {
            lastError = recoveryMessages.joined(separator: " ")
        }
    }

    func cancelRecording() async {
        recordingAttempt += 1
        durationTask?.cancel()
        durationTask = nil
        microphone.stop()
        await session?.cancel()
        await recordingStore?.removeTemporaryRecording(at: activeRecordingURL)
        isRecording = false
        isFinishing = false
        currentDuration = 0
        startedAt = nil
        activeRecordingID = nil
        activeRecordingURL = nil
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
        lastError = nil
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
            isImportingMedia = false
            mediaImportProgress = 0
            mediaImportFileName = ""
        }

        do {
            guard await requestSpeech() else { return }
            try await session.begin(localeIdentifier: localeIdentifier, source: .importedFile)
            let duration = try await mediaReader.read(url: url) { frame in
                try await session.append(frame)
            } onProgress: { [weak self] progress in
                await MainActor.run { self?.mediaImportProgress = progress }
            }
            latestEntry = try await session.finish(duration: duration)
            if let latestEntry { await cloudSync?.save(latestEntry) }
            await refreshHistory()
            session.reset()
        } catch is CancellationError {
            await session.cancel()
        } catch {
            await session.cancel()
            lastError = error.localizedDescription
        }
    }

    func prepareForBackground() async {
        mediaImportTask?.cancel()
        if !isRecording && !isStarting {
            await qwenManager.unload()
        }
    }

    func refreshHistory(query: String = "") async {
        historyQuery = query
        allHistory = await store?.entries() ?? []
        history = await store?.entries(matching: query) ?? []
        guard let recordingStore else {
            audioURLs = [:]
            return
        }
        var urls: [UUID: URL] = [:]
        for entry in allHistory {
            if let url = await recordingStore.fileURL(for: entry) {
                urls[entry.id] = url
            }
        }
        audioURLs = urls
    }

    func delete(_ entry: VoiceEntry) async {
        do {
            if playingEntryID == entry.id { stopPlayback() }
            try await recordingStore?.deleteRecording(for: entry)
            try await store?.delete(id: entry.id)
            await cloudSync?.deleteEntry(id: entry.id)
            await refreshHistory(query: historyQuery)
            if latestEntry?.id == entry.id { latestEntry = allHistory.first }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggleFavorite(_ entry: VoiceEntry) async {
        var updated = entry
        updated.isFavorite.toggle()
        do {
            try await store?.save(updated)
            await cloudSync?.save(updated)
            if latestEntry?.id == updated.id { latestEntry = updated }
            await refreshHistory(query: historyQuery)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func copy(_ entry: VoiceEntry) {
        UIPasteboard.general.string = entry.transcript
    }

    func audioURL(for entry: VoiceEntry) -> URL? {
        audioURLs[entry.id]
    }

    func entry(id: UUID) -> VoiceEntry? {
        allHistory.first { $0.id == id }
    }

    func togglePlayback(_ entry: VoiceEntry) async {
        if playingEntryID == entry.id {
            guard let audioPlayer else { return }
            if audioPlayer.isPlaying {
                audioPlayer.pause()
                playbackTime = audioPlayer.currentTime
            } else {
                audioPlayer.rate = playbackRate
                audioPlayer.play()
            }
            return
        }
        await preparePlayback(entry, autoplay: true)
    }

    func seekPlayback(to time: TimeInterval, entry: VoiceEntry) async {
        if playingEntryID != entry.id {
            await preparePlayback(entry, autoplay: false)
        }
        guard let audioPlayer, playingEntryID == entry.id else { return }
        let clamped = min(max(time, 0), audioPlayer.duration)
        audioPlayer.currentTime = clamped
        playbackTime = clamped
    }

    func skipPlayback(by interval: TimeInterval, entry: VoiceEntry) async {
        let current = playingEntryID == entry.id ? playbackTime : 0
        await seekPlayback(to: current + interval, entry: entry)
    }

    func setPlaybackRate(_ rate: Float) {
        let supportedRates: [Float] = [0.5, 1, 1.5, 2]
        guard supportedRates.contains(rate) else { return }
        playbackRate = rate
        audioPlayer?.enableRate = true
        audioPlayer?.rate = rate
    }

    func updateTitle(_ title: String, for entry: VoiceEntry) async {
        var updated = entry
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.title = trimmed.isEmpty ? nil : trimmed
        do {
            try await store?.save(updated)
            await cloudSync?.save(updated)
            if latestEntry?.id == updated.id { latestEntry = updated }
            await refreshHistory(query: historyQuery)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func preparePlayback(_ entry: VoiceEntry, autoplay: Bool) async {
        let url: URL?
        if let cachedURL = audioURLs[entry.id] {
            url = cachedURL
        } else {
            url = await recordingStore?.fileURL(for: entry)
        }
        guard let url else {
            lastError = "The recording audio is not available on this device yet. Try Sync Now after iCloud finishes."
            return
        }
        do {
            stopPlayback()
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.enableRate = true
            player.rate = playbackRate
            player.prepareToPlay()
            if autoplay, !player.play() {
                throw NSError(
                    domain: "OneVoicePlayback",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "The recording could not start playing."]
                )
            }
            audioPlayer = player
            playingEntryID = entry.id
            playbackTime = player.currentTime
            playbackDuration = player.duration
            startPlaybackUpdates(entryID: entry.id)
        } catch {
            stopPlayback()
            lastError = error.localizedDescription
        }
    }

    private func startPlaybackUpdates(entryID: UUID) {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self,
                      self.playingEntryID == entryID,
                      let player = self.audioPlayer else { return }
                self.playbackTime = player.currentTime
                self.playbackDuration = player.duration
                if !player.isPlaying, player.currentTime >= player.duration - 0.05 {
                    self.stopPlayback()
                    return
                }
            }
        }
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        playingEntryID = nil
        playbackTime = 0
        playbackDuration = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
        do {
            try await dictionaryStore?.delete(id: replacement.id)
            await cloudSync?.deleteReplacement(id: replacement.id)
            replacements = await dictionaryStore?.all() ?? []
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

    private func requestMicrophone() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            if !granted { lastError = "Microphone access is required in Settings → Privacy & Security → Microphone." }
            return granted
        default:
            lastError = "Microphone access is required in Settings → Privacy & Security → Microphone."
            return false
        }
    }

    private func requestSpeech() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            let authorized = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            if !authorized { lastError = "Speech Recognition permission is required." }
            return authorized
        default:
            lastError = "Speech Recognition permission is required."
            return false
        }
    }

    private func rebuildSession() {
        guard let store, !isRecording else { return }
        session = makeSession(store: store)
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
        latestEntry = history.first
        rebuildSession()
    }

    private var cloudContainerIdentifier: String? {
        #if targetEnvironment(simulator)
        nil
        #else
        Bundle.main.object(forInfoDictionaryKey: "OneVoiceCloudContainerIdentifier") as? String
        #endif
    }

    private func makeSession(store: VoiceEntryStore) -> DictationSession {
        DictationSession(
            engine: speechEngine,
            insertion: insertion,
            store: store,
            normalizer: TranscriptNormalizer(replacements: replacements)
        )
    }

    private func failRecording(_ error: Error) async {
        let elapsed = startedAt.map { $0.duration(to: .now).timeInterval } ?? currentDuration
        if isRecording, elapsed > 0 {
            currentDuration = elapsed
            await finishRecording()
            lastError = "Recording stopped because the audio session changed. The captured audio was saved. \(error.localizedDescription)"
        } else {
            lastError = error.localizedDescription
            await cancelRecording()
        }
    }

    private func suggestedTitle(for transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallbackRecordingTitle() }
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        return String(firstLine.prefix(60))
    }

    private func fallbackRecordingTitle() -> String {
        let locale = AppLanguage.current.locale
        let prefix = String(localized: "Recording", locale: locale)
        let date = Date().formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)
        )
        return "\(prefix) \(date)"
    }

    private func validatedAudioDuration(at url: URL) throws -> TimeInterval {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let byteCount = values.fileSize, byteCount > 0 else {
            throw NSError(
                domain: "OneVoiceRecordingValidation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The audio file is empty."]
            )
        }
        let player = try AVAudioPlayer(contentsOf: url)
        guard player.prepareToPlay(), player.duration > 0, player.duration.isFinite else {
            throw NSError(
                domain: "OneVoiceRecordingValidation",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "The audio file is not playable."]
            )
        }
        return player.duration
    }

    private func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(
            path: Self.applicationSupportDirectoryName,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static var applicationSupportDirectoryName: String {
        #if DEBUG
        "OneVoice Dev"
        #else
        "OneVoice"
        #endif
    }

    private static var qwenModelDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appending(path: "Library/Application Support")
        return base
            .appending(path: applicationSupportDirectoryName, directoryHint: .isDirectory)
            .appending(path: "Models", directoryHint: .isDirectory)
            .appending(path: "Qwen3-ASR-0.6B-MLX-4bit", directoryHint: .isDirectory)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
