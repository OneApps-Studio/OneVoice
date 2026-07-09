import Foundation

public struct DictionaryReplacement: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var spoken: String
    public var written: String

    public init(id: UUID = UUID(), spoken: String, written: String) {
        self.id = id
        self.spoken = spoken
        self.written = written
    }
}

public actor DictionaryReplacementStore {
    private let fileURL: URL
    private var replacements: [DictionaryReplacement]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            replacements = try JSONDecoder().decode([DictionaryReplacement].self, from: data)
        } else {
            replacements = []
        }
    }

    public func all() -> [DictionaryReplacement] {
        replacements.sorted {
            $0.spoken.localizedCaseInsensitiveCompare($1.spoken) == .orderedAscending
        }
    }

    public func save(_ replacement: DictionaryReplacement) throws {
        if let index = replacements.firstIndex(where: { $0.id == replacement.id }) {
            replacements[index] = replacement
        } else {
            replacements.append(replacement)
        }
        try persist()
    }

    public func delete(id: UUID) throws {
        replacements.removeAll { $0.id == id }
        try persist()
    }

    private func persist() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(replacements)
        try data.write(to: fileURL, options: .atomic)
    }
}
