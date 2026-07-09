import Foundation
import OneVoiceCore
import Testing

@Suite("Voice entry store")
struct VoiceEntryStoreTests {
    @Test("Saved entries survive reopening and newest entries are returned first")
    func persistenceAndOrdering() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

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
}
