import Foundation
import OneVoiceCore
import Testing

@Suite("Voice recording store")
struct VoiceRecordingStoreTests {
    @Test("Active recordings live in a durable pending folder and are discoverable after relaunch")
    func pendingRecordingRecovery() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "OneVoice App Support \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let entryID = UUID()
        let firstStore = VoiceRecordingStore(directoryURL: root.appending(path: "Recordings"))
        let pendingURL = try await firstStore.pendingRecordingURL(id: entryID)
        try Data([0x01, 0x02, 0x03, 0x04]).write(to: pendingURL)

        let relaunchedStore = VoiceRecordingStore(directoryURL: root.appending(path: "Recordings"))
        let pending = try await relaunchedStore.pendingRecordings()
        #expect(pending.count == 1)
        #expect(pending.first?.id == entryID)
        #expect(pending.first?.byteCount == 4)
        #expect(
            pending.first?.fileURL.resolvingSymlinksInPath().path()
                == pendingURL.resolvingSymlinksInPath().path()
        )

        let committed = try await relaunchedStore.commitRecording(from: pendingURL, id: entryID)
        #expect(committed.fileName == "\(entryID.uuidString.lowercased()).m4a")
        #expect(try await relaunchedStore.pendingRecordings().isEmpty)

        let orphaned = try await relaunchedStore.unindexedRecordings(referencedEntryIDs: [])
        #expect(orphaned.count == 1)
        #expect(orphaned.first?.id == entryID)
        #expect(orphaned.first?.file.byteCount == 4)
        #expect(try await relaunchedStore.unindexedRecordings(referencedEntryIDs: [entryID]).isEmpty)
    }

    @Test("A completed recording is moved into the library and deleted with its entry")
    func commitAndDeleteRecording() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let temporaryURL = root.appending(path: "capture.m4a")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data([0x01, 0x02, 0x03, 0x04]).write(to: temporaryURL)

        let entryID = UUID()
        let store = VoiceRecordingStore(directoryURL: root.appending(path: "Recordings"))
        let recording = try await store.commitRecording(from: temporaryURL, id: entryID)

        #expect(recording.fileName == "\(entryID.uuidString.lowercased()).m4a")
        #expect(recording.byteCount == 4)
        #expect(try Data(contentsOf: recording.fileURL) == Data([0x01, 0x02, 0x03, 0x04]))
        #expect(!FileManager.default.fileExists(atPath: temporaryURL.path()))

        let entry = VoiceEntry(
            id: entryID,
            rawTranscript: "hello",
            transcript: "Hello.",
            duration: 1,
            localeIdentifier: "en-US",
            engineIdentifier: "apple",
            source: .voiceNote,
            title: "Hello",
            audioFileName: recording.fileName,
            audioByteCount: recording.byteCount
        )
        #expect(await store.fileURL(for: entry) == recording.fileURL)

        try await store.deleteRecording(for: entry)
        #expect(!FileManager.default.fileExists(atPath: recording.fileURL.path()))
    }

    @Test("A CloudKit staging asset is copied before the staging file disappears")
    func importCloudAsset() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let stagingURL = root.appending(path: "cloud-asset")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("synced audio".utf8).write(to: stagingURL)

        let entryID = UUID()
        let store = VoiceRecordingStore(directoryURL: root.appending(path: "Recordings"))
        let recording = try await store.importCloudAsset(from: stagingURL, id: entryID)

        #expect(FileManager.default.fileExists(atPath: stagingURL.path()))
        #expect(try Data(contentsOf: recording.fileURL) == Data("synced audio".utf8))
    }
}
