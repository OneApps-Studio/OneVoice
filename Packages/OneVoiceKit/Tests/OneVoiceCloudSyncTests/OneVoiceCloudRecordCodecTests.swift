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
}
