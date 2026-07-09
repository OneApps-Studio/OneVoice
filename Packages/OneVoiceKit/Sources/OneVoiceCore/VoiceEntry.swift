import Foundation

public struct VoiceEntry: Codable, Identifiable, Sendable, Equatable {
    public enum Source: String, Codable, Sendable, CaseIterable {
        case quickDictation
        case voiceNote
        case importedFile
    }

    public let id: UUID
    public var rawTranscript: String
    public var transcript: String
    public var createdAt: Date
    public var duration: TimeInterval
    public var localeIdentifier: String
    public var engineIdentifier: String
    public var source: Source
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        rawTranscript: String,
        transcript: String,
        createdAt: Date = Date(),
        duration: TimeInterval,
        localeIdentifier: String,
        engineIdentifier: String,
        source: Source,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.rawTranscript = rawTranscript
        self.transcript = transcript
        self.createdAt = createdAt
        self.duration = duration
        self.localeIdentifier = localeIdentifier
        self.engineIdentifier = engineIdentifier
        self.source = source
        self.isFavorite = isFavorite
    }
}
