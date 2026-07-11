@preconcurrency import CloudKit
import Foundation
@testable import OneVoiceCloudSync
import OneVoiceCore
import Testing

@Suite("Cloud record codec")
struct OneVoiceCloudRecordCodecTests {
    private let zoneID = CKRecordZone.ID(zoneName: "TestZone")

    @Test("Voice entries round trip through CloudKit records")
    func entryRoundTrip() throws {
        let assetURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("m4a")
        try Data("recording".utf8).write(to: assetURL)
        defer { try? FileManager.default.removeItem(at: assetURL) }
        let entry = VoiceEntry(
            rawTranscript: "one voice",
            transcript: "OneVoice",
            duration: 12.5,
            localeIdentifier: "en-US",
            engineIdentifier: "apple",
            source: .importedFile,
            isFavorite: true,
            title: "OneVoice recording",
            audioFileName: assetURL.lastPathComponent,
            audioByteCount: 9
        )
        let record = OneVoiceCloudRecordCodec.record(
            for: entry,
            zoneID: zoneID,
            audioFileURL: assetURL
        )
        let decoded = try #require(OneVoiceCloudRecordCodec.entry(from: record))
        #expect(decoded == entry)
        let asset = try #require(record["audioAsset"] as? CKAsset)
        #expect(asset.fileURL == assetURL)
    }

    @Test("Dictionary replacements round trip through CloudKit records")
    func replacementRoundTrip() throws {
        let replacement = DictionaryReplacement(spoken: "one voice", written: "OneVoice")
        let record = OneVoiceCloudRecordCodec.record(for: replacement, zoneID: zoneID)
        let decoded = try #require(OneVoiceCloudRecordCodec.replacement(from: record))
        #expect(decoded == replacement)
    }

    @Test("Only saved voice notes are eligible for CloudKit")
    func cloudPrivacyPolicy() {
        let voiceNote = makeEntry(source: .voiceNote)
        let quickDictation = makeEntry(source: .quickDictation)
        let importedFile = makeEntry(source: .importedFile)

        #expect(OneVoiceCloudRecordPolicy.shouldSync(voiceNote))
        #expect(!OneVoiceCloudRecordPolicy.shouldSync(quickDictation))
        #expect(!OneVoiceCloudRecordPolicy.shouldSync(importedFile))
    }

    @Test("Sync journal coalesces offline mutations and only acknowledges matching work")
    func syncJournalCoalescesMutations() {
        var journal = OneVoiceCloudSyncJournal()

        journal.stageLocal(recordName: "entry_one", action: .save)
        journal.stageLocal(recordName: "entry_one", action: .delete)
        journal.acknowledgeLocal(recordName: "entry_one", action: .save)
        #expect(journal.localMutations["entry_one"]?.action == .delete)

        journal.stageRemoteRetry(recordName: "entry_two", action: .save)
        journal.stageRemoteRetry(recordName: "entry_two", action: .delete)
        journal.acknowledgeRemoteRetry(recordName: "entry_two", action: .save)
        #expect(journal.remoteRetries["entry_two"]?.action == .delete)

        journal.acknowledgeLocal(recordName: "entry_one", action: .delete)
        journal.acknowledgeRemoteRetry(recordName: "entry_two", action: .delete)
        #expect(journal.localMutations.isEmpty)
        #expect(journal.remoteRetries.isEmpty)
    }

    private func makeEntry(source: VoiceEntry.Source) -> VoiceEntry {
        VoiceEntry(
            rawTranscript: "raw",
            transcript: "text",
            duration: 1,
            localeIdentifier: "en-US",
            engineIdentifier: "apple",
            source: source
        )
    }
}
