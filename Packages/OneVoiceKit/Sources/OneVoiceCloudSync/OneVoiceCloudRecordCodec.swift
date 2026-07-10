@preconcurrency import CloudKit
import Foundation
import OneVoiceCore

enum OneVoiceCloudRecordCodec {
    static let entryRecordType = "VoiceEntry"
    static let replacementRecordType = "DictionaryReplacement"

    static func entryRecordID(_ id: UUID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "entry_\(id.uuidString.lowercased())", zoneID: zoneID)
    }

    static func replacementRecordID(_ id: UUID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "replacement_\(id.uuidString.lowercased())", zoneID: zoneID)
    }

    static func record(
        for entry: VoiceEntry,
        zoneID: CKRecordZone.ID,
        audioFileURL: URL? = nil,
        existingRecord: CKRecord? = nil
    ) -> CKRecord {
        let record = existingRecord ?? CKRecord(
            recordType: entryRecordType,
            recordID: entryRecordID(entry.id, zoneID: zoneID)
        )
        record["id"] = entry.id.uuidString as CKRecordValue
        record["rawTranscript"] = entry.rawTranscript as CKRecordValue
        record["transcript"] = entry.transcript as CKRecordValue
        record["createdAt"] = entry.createdAt as CKRecordValue
        record["duration"] = entry.duration as CKRecordValue
        record["localeIdentifier"] = entry.localeIdentifier as CKRecordValue
        record["engineIdentifier"] = entry.engineIdentifier as CKRecordValue
        record["source"] = entry.source.rawValue as CKRecordValue
        record["isFavorite"] = NSNumber(value: entry.isFavorite)
        if let title = entry.title {
            record["title"] = title as CKRecordValue
        } else {
            record["title"] = nil
        }
        if let audioFileName = entry.audioFileName {
            record["audioFileName"] = audioFileName as CKRecordValue
        } else {
            record["audioFileName"] = nil
        }
        if let audioByteCount = entry.audioByteCount {
            record["audioByteCount"] = NSNumber(value: audioByteCount)
        } else {
            record["audioByteCount"] = nil
        }
        if let audioFileURL {
            record["audioAsset"] = CKAsset(fileURL: audioFileURL)
        } else if entry.audioFileName == nil {
            record["audioAsset"] = nil
        }
        return record
    }

    static func record(for replacement: DictionaryReplacement, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: replacementRecordType,
            recordID: replacementRecordID(replacement.id, zoneID: zoneID)
        )
        record["id"] = replacement.id.uuidString as CKRecordValue
        record["spoken"] = replacement.spoken as CKRecordValue
        record["written"] = replacement.written as CKRecordValue
        return record
    }

    static func entry(from record: CKRecord) -> VoiceEntry? {
        guard record.recordType == entryRecordType,
              let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let rawTranscript = record["rawTranscript"] as? String,
              let transcript = record["transcript"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let duration = record["duration"] as? Double,
              let localeIdentifier = record["localeIdentifier"] as? String,
              let engineIdentifier = record["engineIdentifier"] as? String,
              let sourceValue = record["source"] as? String,
              let source = VoiceEntry.Source(rawValue: sourceValue) else {
            return nil
        }
        return VoiceEntry(
            id: id,
            rawTranscript: rawTranscript,
            transcript: transcript,
            createdAt: createdAt,
            duration: duration,
            localeIdentifier: localeIdentifier,
            engineIdentifier: engineIdentifier,
            source: source,
            isFavorite: (record["isFavorite"] as? NSNumber)?.boolValue ?? false,
            title: record["title"] as? String,
            audioFileName: record["audioFileName"] as? String,
            audioByteCount: (record["audioByteCount"] as? NSNumber)?.int64Value
        )
    }

    static func replacement(from record: CKRecord) -> DictionaryReplacement? {
        guard record.recordType == replacementRecordType,
              let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let spoken = record["spoken"] as? String,
              let written = record["written"] as? String else {
            return nil
        }
        return DictionaryReplacement(id: id, spoken: spoken, written: written)
    }

    static func localIdentifier(for recordID: CKRecord.ID) -> (kind: Kind, id: UUID)? {
        let components = recordID.recordName.split(separator: "_", maxSplits: 1).map(String.init)
        guard components.count == 2, let id = UUID(uuidString: components[1]) else { return nil }
        switch components[0] {
        case "entry": return (.entry, id)
        case "replacement": return (.replacement, id)
        default: return nil
        }
    }

    enum Kind {
        case entry
        case replacement
    }
}
