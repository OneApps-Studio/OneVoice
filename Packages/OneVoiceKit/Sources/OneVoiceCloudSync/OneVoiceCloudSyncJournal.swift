import Foundation
import OneVoiceCore

enum OneVoiceCloudRecordPolicy {
    static func shouldSync(_ entry: VoiceEntry) -> Bool {
        entry.source == .voiceNote
    }
}

struct OneVoiceCloudSyncJournal: Codable, Equatable {
    enum Action: String, Codable, Equatable {
        case save
        case delete
    }

    struct Mutation: Codable, Equatable {
        let recordName: String
        let action: Action
    }

    private(set) var localMutations: [String: Mutation] = [:]
    private(set) var remoteRetries: [String: Mutation] = [:]

    mutating func stageLocal(recordName: String, action: Action) {
        localMutations[recordName] = Mutation(recordName: recordName, action: action)
    }

    mutating func acknowledgeLocal(recordName: String, action: Action) {
        guard localMutations[recordName]?.action == action else { return }
        localMutations[recordName] = nil
    }

    mutating func stageRemoteRetry(recordName: String, action: Action) {
        remoteRetries[recordName] = Mutation(recordName: recordName, action: action)
    }

    mutating func acknowledgeRemoteRetry(recordName: String, action: Action) {
        guard remoteRetries[recordName]?.action == action else { return }
        remoteRetries[recordName] = nil
    }
}
