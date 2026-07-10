import Foundation
import Observation

@MainActor
@Observable
public final class DictationSession {
    public enum State: Sendable, Equatable {
        case idle
        case preparing
        case listening
        case finalizing
        case completed
        case failed(String)
    }

    public enum SessionError: LocalizedError, Sendable, Equatable {
        case alreadyRunning
        case notRunning
        case emptyTranscript

        public var errorDescription: String? {
            switch self {
            case .alreadyRunning: "A dictation session is already running."
            case .notRunning: "No dictation session is running."
            case .emptyTranscript: "No speech was detected."
            }
        }
    }

    public private(set) var state: State = .idle
    public private(set) var partialTranscript = ""
    public private(set) var lastInsertionOutcome: TextInsertionOutcome?

    private let engine: any TranscriptionEngine
    private let insertion: any TextInsertion
    private let store: VoiceEntryStore
    private let normalizer: TranscriptNormalizer
    private var insertionTarget: TextInsertionTarget?
    private var localeIdentifier = "en-US"
    private var source: VoiceEntry.Source = .quickDictation
    private var updateTask: Task<Void, Never>?

    public init(
        engine: any TranscriptionEngine,
        insertion: any TextInsertion,
        store: VoiceEntryStore,
        normalizer: TranscriptNormalizer = TranscriptNormalizer()
    ) {
        self.engine = engine
        self.insertion = insertion
        self.store = store
        self.normalizer = normalizer
    }

    public func begin(
        localeIdentifier: String,
        source: VoiceEntry.Source
    ) async throws {
        guard state == .idle || state == .completed else {
            throw SessionError.alreadyRunning
        }

        state = .preparing
        partialTranscript = ""
        lastInsertionOutcome = nil
        self.localeIdentifier = localeIdentifier
        self.source = source
        insertionTarget = source == .quickDictation ? insertion.captureTarget() : nil

        do {
            let updates = try await engine.start(localeIdentifier: localeIdentifier)
            try Task.checkCancellation()
            guard state == .preparing else {
                await engine.cancel()
                throw CancellationError()
            }
            state = .listening
            updateTask = Task { [weak self] in
                do {
                    for try await update in updates {
                        guard !Task.isCancelled else { return }
                        self?.partialTranscript = update.text
                    }
                } catch is CancellationError {
                    return
                } catch {
                    self?.state = .failed(error.localizedDescription)
                }
            }
        } catch is CancellationError {
            await engine.cancel()
            state = .idle
            insertionTarget = nil
            throw CancellationError()
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    public func append(_ frame: AudioFrame) async throws {
        guard state == .listening else { throw SessionError.notRunning }
        try await engine.append(frame)
    }

    @discardableResult
    public func finish(
        duration: TimeInterval,
        id: UUID = UUID(),
        title: String? = nil,
        audioFileName: String? = nil,
        audioByteCount: Int64? = nil
    ) async throws -> VoiceEntry {
        guard state == .listening else { throw SessionError.notRunning }
        state = .finalizing

        do {
            let transcript = try await engine.finish()
            let rawTranscript = transcript.text
            updateTask?.cancel()
            updateTask = nil
            let finalTranscript = normalizer.normalize(rawTranscript)
            guard !finalTranscript.isEmpty else {
                state = .idle
                throw SessionError.emptyTranscript
            }

            let entry = VoiceEntry(
                id: id,
                rawTranscript: rawTranscript,
                transcript: finalTranscript,
                duration: duration,
                localeIdentifier: localeIdentifier,
                engineIdentifier: transcript.engineIdentifier,
                source: source,
                title: title,
                audioFileName: audioFileName,
                audioByteCount: audioByteCount
            )
            if source == .quickDictation {
                lastInsertionOutcome = await insertion.insert(finalTranscript, into: insertionTarget)
            } else {
                lastInsertionOutcome = nil
            }
            try await store.save(entry)
            insertionTarget = nil
            partialTranscript = finalTranscript
            state = .completed
            return entry
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    public func cancel() async {
        updateTask?.cancel()
        updateTask = nil
        await engine.cancel()
        insertionTarget = nil
        partialTranscript = ""
        lastInsertionOutcome = nil
        state = .idle
    }

    public func reset() {
        guard state == .completed || isFailed else { return }
        partialTranscript = ""
        state = .idle
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }
}
