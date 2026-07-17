import Foundation
import OneVoiceCore
import Testing

@Suite("Voice entry store")
struct VoiceEntryStoreTests {
    @Test("Saved entries survive reopening and newest entries are returned first")
    func persistenceAndOrdering() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "OneVoice App Support \(UUID().uuidString)")
        let fileURL = root.appending(path: "history.json")
        defer { try? FileManager.default.removeItem(at: root) }

        let older = VoiceEntry(
            id: UUID(),
            rawTranscript: "hello world",
            transcript: "Hello world.",
            createdAt: Date(timeIntervalSince1970: 100),
            duration: 1.2,
            localeIdentifier: "en-US",
            engineIdentifier: "apple",
            source: .quickDictation
        )
        let newer = VoiceEntry(
            id: UUID(),
            rawTranscript: "你好 OneVoice",
            transcript: "你好，OneVoice。",
            createdAt: Date(timeIntervalSince1970: 200),
            duration: 2.4,
            localeIdentifier: "zh-Hans",
            engineIdentifier: "qwen3-asr-0.6b",
            source: .voiceNote
        )

        let store = try await VoiceEntryStore(fileURL: fileURL)
        try await store.save(older)
        try await store.save(newer)

        let reopened = try await VoiceEntryStore(fileURL: fileURL)
        #expect(await reopened.entries() == [newer, older])
    }

    @Test("Search matches titles, normalized transcripts, and raw transcripts")
    func searchesEveryUserFacingTextField() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "OneVoice Search \(UUID().uuidString)")
        let fileURL = root.appending(path: "history.json")
        defer { try? FileManager.default.removeItem(at: root) }

        let titleMatch = VoiceEntry(
            rawTranscript: "first raw value",
            transcript: "First normalized value",
            createdAt: Date(timeIntervalSince1970: 1),
            duration: 1,
            localeIdentifier: "en-US",
            engineIdentifier: "apple",
            source: .voiceNote,
            title: "Project Aurora"
        )
        let transcriptMatch = VoiceEntry(
            rawTranscript: "第二段原始文本",
            transcript: "明天下午确认发布计划",
            createdAt: Date(timeIntervalSince1970: 2),
            duration: 2,
            localeIdentifier: "zh-Hans",
            engineIdentifier: "apple",
            source: .voiceNote
        )
        let rawMatch = VoiceEntry(
            rawTranscript: "Codex migration note",
            transcript: "Migration note",
            createdAt: Date(timeIntervalSince1970: 3),
            duration: 3,
            localeIdentifier: "en-US",
            engineIdentifier: "qwen",
            source: .voiceNote
        )

        let store = try await VoiceEntryStore(fileURL: fileURL)
        try await store.save(titleMatch)
        try await store.save(transcriptMatch)
        try await store.save(rawMatch)

        #expect(await store.entries(matching: "aurora") == [titleMatch])
        #expect(await store.entries(matching: "发布计划") == [transcriptMatch])
        #expect(await store.entries(matching: "Codex") == [rawMatch])
        #expect(await store.entries(matching: "  ") == [rawMatch, transcriptMatch, titleMatch])
    }

    @Test("Version 1.0 history without audio fields remains readable")
    func decodesLegacyHistory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "OneVoice Legacy \(UUID().uuidString)")
        let fileURL = root.appending(path: "history.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let id = UUID()
        let legacyJSON = """
        [{
          "id": "\(id.uuidString)",
          "rawTranscript": "legacy raw",
          "transcript": "Legacy transcript",
          "createdAt": "2026-01-02T03:04:05Z",
          "duration": 4.5,
          "localeIdentifier": "en-US",
          "engineIdentifier": "apple",
          "source": "quickDictation",
          "isFavorite": false
        }]
        """
        try Data(legacyJSON.utf8).write(to: fileURL)

        let store = try await VoiceEntryStore(fileURL: fileURL)
        let entry = try #require(await store.entry(id: id))
        #expect(entry.transcript == "Legacy transcript")
        #expect(entry.title == nil)
        #expect(entry.audioFileName == nil)
        #expect(entry.audioByteCount == nil)
    }
}
