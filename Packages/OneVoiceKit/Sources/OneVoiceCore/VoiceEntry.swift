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
    public var title: String?
    public var audioFileName: String?
    public var audioByteCount: Int64?

    public init(
        id: UUID = UUID(),
        rawTranscript: String,
        transcript: String,
        createdAt: Date = Date(),
        duration: TimeInterval,
        localeIdentifier: String,
        engineIdentifier: String,
        source: Source,
        isFavorite: Bool = false,
        title: String? = nil,
        audioFileName: String? = nil,
        audioByteCount: Int64? = nil
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
        self.title = title
        self.audioFileName = audioFileName
        self.audioByteCount = audioByteCount
    }

    public var hasAudio: Bool {
        audioFileName?.isEmpty == false
    }

    public var displayTitle: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        let firstLine = transcript.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        if !firstLine.isEmpty {
            return String(firstLine.prefix(80))
        }
        return "Untitled Recording"
    }
}
