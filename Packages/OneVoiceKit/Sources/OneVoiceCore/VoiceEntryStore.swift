import Foundation

public actor VoiceEntryStore {
    private let fileURL: URL
    private var storedEntries: [VoiceEntry]
    private let encoder: JSONEncoder

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601

        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            self.storedEntries = []
            return
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.storedEntries = try decoder.decode([VoiceEntry].self, from: data)
        self.storedEntries.sort { $0.createdAt > $1.createdAt }
    }

    public func entries(matching query: String? = nil) -> [VoiceEntry] {
        guard let query = query?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty
        else {
            return storedEntries
        }

        return storedEntries.filter {
            $0.transcript.localizedCaseInsensitiveContains(query) ||
                $0.rawTranscript.localizedCaseInsensitiveContains(query)
        }
    }

    public func save(_ entry: VoiceEntry) throws {
        storedEntries.removeAll { $0.id == entry.id }
        storedEntries.append(entry)
        storedEntries.sort { $0.createdAt > $1.createdAt }
        try persist()
    }

    public func delete(id: UUID) throws {
        storedEntries.removeAll { $0.id == id }
        try persist()
    }

    public func removeAll() throws {
        storedEntries.removeAll()
        try persist()
    }

    private func persist() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(storedEntries)
        try data.write(to: fileURL, options: [.atomic])
    }
}
