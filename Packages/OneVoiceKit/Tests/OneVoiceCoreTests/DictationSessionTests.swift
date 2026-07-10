import Foundation
import OneVoiceCore
import Testing

@MainActor
@Suite("Dictation session")
struct DictationSessionTests {
    @Test("Finishing inserts normalized text and saves the same result to history")
    func finishInsertsAndSaves() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let engine = StubTranscriptionEngine(finalText: "  hello OneVoice  ")
        let insertion = StubTextInsertion()
        let store = try await VoiceEntryStore(fileURL: fileURL)
        let session = DictationSession(
            engine: engine,
            insertion: insertion,
            store: store,
            normalizer: TranscriptNormalizer()
        )

        try await session.begin(localeIdentifier: "en-US", source: .quickDictation)
        try await session.append(AudioFrame(samples: [0.1, -0.1], sampleRate: 16_000))
        let result = try await session.finish(duration: 1.5)

        #expect(result.transcript == "hello OneVoice")
        #expect(result.engineIdentifier == "stub-final")
        #expect(insertion.insertedText == "hello OneVoice")
        #expect(await store.entries().first?.transcript == "hello OneVoice")
        #expect(await engine.receivedFrameCount == 1)
    }

    @Test("Imported media is saved without inserting into the focused app")
    func importedMediaDoesNotInsert() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let engine = StubTranscriptionEngine(finalText: "Imported transcript")
        let insertion = StubTextInsertion()
        let store = try await VoiceEntryStore(fileURL: fileURL)
        let session = DictationSession(engine: engine, insertion: insertion, store: store)

        try await session.begin(localeIdentifier: "en-US", source: .importedFile)
        try await session.append(AudioFrame(samples: [0.1], sampleRate: 16_000))
        let result = try await session.finish(duration: 2)

        #expect(result.source == .importedFile)
        #expect(insertion.insertedText == nil)
        #expect(session.lastInsertionOutcome == nil)
        #expect(await store.entries().first?.transcript == "Imported transcript")
    }

    @Test("A voice note keeps its recording identity and metadata after automatic transcription")
    func voiceNoteKeepsRecordingMetadata() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let engine = StubTranscriptionEngine(finalText: "Planning the next release")
        let insertion = StubTextInsertion()
        let store = try await VoiceEntryStore(fileURL: fileURL)
        let session = DictationSession(engine: engine, insertion: insertion, store: store)
        let id = UUID()

        try await session.begin(localeIdentifier: "en-US", source: .voiceNote)
        try await session.append(AudioFrame(samples: [0.1], sampleRate: 16_000))
        let result = try await session.finish(
            duration: 4.2,
            id: id,
            title: "Planning the next release",
            audioFileName: "\(id.uuidString.lowercased()).m4a",
            audioByteCount: 42
        )

        #expect(result.id == id)
        #expect(result.source == .voiceNote)
        #expect(result.title == "Planning the next release")
        #expect(result.audioFileName == "\(id.uuidString.lowercased()).m4a")
        #expect(result.audioByteCount == 42)
        #expect(insertion.insertedText == nil)
    }
}

private actor StubTranscriptionEngine: TranscriptionEngine {
    nonisolated let identifier = "stub-live"
    private let finalText: String
    private(set) var receivedFrameCount = 0

    init(finalText: String) {
        self.finalText = finalText
    }

    func start(localeIdentifier: String) async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.init(text: "hello", isFinal: false))
        }
    }

    func append(_ frame: AudioFrame) async throws {
        receivedFrameCount += 1
    }

    func finish() async throws -> Transcript {
        Transcript(text: finalText, engineIdentifier: "stub-final")
    }

    func cancel() async {}
}

@MainActor
private final class StubTextInsertion: TextInsertion {
    private(set) var insertedText: String?

    func captureTarget() -> TextInsertionTarget? {
        TextInsertionTarget(id: UUID())
    }

    func insert(_ text: String, into target: TextInsertionTarget?) async -> TextInsertionOutcome {
        insertedText = text
        return .insertedDirectly
    }
}
