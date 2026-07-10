import Foundation
import OneVoiceQwenSpeech
import Testing

@Suite("Qwen model integrity")
struct QwenModelManagerTests {
    @Test("A same-sized but corrupted artifact is rejected before model loading")
    func rejectsCorruptedArtifact() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let expectedSizes: [String: UInt64] = [
            "config.json": 7_187,
            "merges.txt": 1_671_853,
            "model.safetensors": 708_236_945,
            "model.safetensors.index.json": 71_814,
            "tokenizer_config.json": 12_487,
            "vocab.json": 2_776_833,
        ]
        for (name, size) in expectedSizes {
            let url = directory.appending(path: name)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            let handle = try FileHandle(forWritingTo: url)
            try handle.truncate(atOffset: size)
            try handle.close()
        }

        let manager = QwenModelManager(cacheDirectory: directory)
        #expect(await manager.isInstalled())

        do {
            _ = try await manager.transcribe(audio: [], language: "English")
            Issue.record("A corrupted pinned model artifact was accepted")
        } catch let error as QwenModelManager.ManagerError {
            guard case .invalidDownload("config.json") = error else {
                Issue.record("Unexpected integrity error: \(error.localizedDescription)")
                return
            }
        }
    }
}
