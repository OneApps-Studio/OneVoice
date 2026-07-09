import AVFoundation
import Foundation
import Observation
import OneVoiceAppleSpeech
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
    private(set) var currentDuration: TimeInterval = 0
    private(set) var history: [VoiceEntry] = []
    private(set) var replacements: [DictionaryReplacement] = []
    private(set) var latestEntry: VoiceEntry?
    private(set) var qwenInstalled = false
    private(set) var qwenIsDownloading = false
    private(set) var qwenDownloadProgress = 0.0
    private(set) var qwenStatusText = "Not installed"
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
    var liveTranscript: String { session?.partialTranscript ?? "" }

    private let qwenManager: QwenModelManager
    private let speechEngine: HybridTranscriptionEngine
    private let microphone = MobileMicrophoneCapture()
    private let insertion = MobileClipboardInsertion()
    private var store: VoiceEntryStore?
    private var dictionaryStore: DictionaryReplacementStore?
    private var session: DictationSession?
    private var startedAt: ContinuousClock.Instant?
    private var durationTask: Task<Void, Never>?
    private var didLaunch = false
    private var recordingAttempt = 0

    private init() {
        let qwenManager = QwenModelManager()
        let qwenEnabled = UserDefaults.standard.object(forKey: "onevoice.useQwenFinalPass") as? Bool ?? true
        self.qwenManager = qwenManager
        speechEngine = HybridTranscriptionEngine(
            liveEngine: AppleSpeechTranscriptionEngine(),
            qwenManager: qwenManager,
            useQwenFinalPass: qwenEnabled
        )
        useQwenFinalPass = qwenEnabled
        localeIdentifier = UserDefaults.standard.string(forKey: "onevoice.recognitionLocale") ?? "zh-Hans"
    }

    func launch() async {
        guard !didLaunch else { return }
        didLaunch = true
        do {
            let support = try applicationSupportDirectory()
            let store = try await VoiceEntryStore(fileURL: support.appending(path: "history.json"))
            let dictionaryStore = try await DictionaryReplacementStore(
                fileURL: support.appending(path: "dictionary.json")
            )
            self.store = store
            self.dictionaryStore = dictionaryStore
            replacements = await dictionaryStore.all()
            qwenInstalled = await qwenManager.isInstalled()
            qwenStatusText = qwenInstalled ? "Installed" : "Not installed"
            session = makeSession(store: store)
            await refreshHistory()
            latestEntry = history.first
            isReady = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func startRecording() async {
        guard isReady, !isStarting, !isRecording, !isFinishing, let session else { return }
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
            try await session.begin(localeIdentifier: localeIdentifier, source: .voiceNote)
            guard attempt == recordingAttempt else {
                await session.cancel()
                return
            }
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
        } catch {
            microphone.stop()
            await session.cancel()
            lastError = error.localizedDescription
        }
    }

    func finishRecording() async {
        guard isRecording, let session else { return }
        isRecording = false
        isFinishing = true
        durationTask?.cancel()
        durationTask = nil
        microphone.stop()
        do {
            latestEntry = try await session.finish(duration: currentDuration)
            await refreshHistory()
        } catch {
            lastError = error.localizedDescription
        }
        isFinishing = false
        startedAt = nil
        session.reset()
    }

    func cancelRecording() async {
        recordingAttempt += 1
        durationTask?.cancel()
        durationTask = nil
        microphone.stop()
        await session?.cancel()
        isRecording = false
        isFinishing = false
        currentDuration = 0
        startedAt = nil
    }

    func prepareForBackground() async {
        if isRecording || isStarting {
            await cancelRecording()
        }
        await qwenManager.unload()
    }

    func refreshHistory(query: String = "") async {
        history = await store?.entries(matching: query) ?? []
    }

    func delete(_ entry: VoiceEntry) async {
        do {
            try await store?.delete(id: entry.id)
            await refreshHistory()
            if latestEntry?.id == entry.id { latestEntry = history.first }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggleFavorite(_ entry: VoiceEntry) async {
        var updated = entry
        updated.isFavorite.toggle()
        do {
            try await store?.save(updated)
            if latestEntry?.id == updated.id { latestEntry = updated }
            await refreshHistory()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func copy(_ entry: VoiceEntry) {
        UIPasteboard.general.string = entry.transcript
    }

    func saveReplacement(spoken: String, written: String) async {
        let spoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let written = written.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty, !written.isEmpty, let dictionaryStore else { return }
        do {
            try await dictionaryStore.save(.init(spoken: spoken, written: written))
            replacements = await dictionaryStore.all()
            rebuildSession()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteReplacement(_ replacement: DictionaryReplacement) async {
        do {
            try await dictionaryStore?.delete(id: replacement.id)
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

    private func makeSession(store: VoiceEntryStore) -> DictationSession {
        DictationSession(
            engine: speechEngine,
            insertion: insertion,
            store: store,
            normalizer: TranscriptNormalizer(replacements: replacements)
        )
    }

    private func failRecording(_ error: Error) async {
        lastError = error.localizedDescription
        await cancelRecording()
    }

    private func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(path: "OneVoice", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
