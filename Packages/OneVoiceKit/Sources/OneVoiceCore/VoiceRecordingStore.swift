import Foundation

public struct VoiceRecordingFile: Sendable, Equatable {
    public let fileName: String
    public let fileURL: URL
    public let byteCount: Int64

    public init(fileName: String, fileURL: URL, byteCount: Int64) {
        self.fileName = fileName
        self.fileURL = fileURL
        self.byteCount = byteCount
    }
}

public actor VoiceRecordingStore {
    private let directoryURL: URL
    private let fileManager: FileManager

    public init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    public func commitRecording(from temporaryURL: URL, id: UUID) throws -> VoiceRecordingFile {
        try prepareDirectory()
        let destinationURL = destinationURL(for: id)
        if fileManager.fileExists(atPath: destinationURL.path()) {
            try fileManager.removeItem(at: destinationURL)
        }
        do {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try fileManager.copyItem(at: temporaryURL, to: destinationURL)
            try fileManager.removeItem(at: temporaryURL)
        }
        return try recordingFile(at: destinationURL)
    }

    public func importCloudAsset(from stagingURL: URL, id: UUID) throws -> VoiceRecordingFile {
        try prepareDirectory()
        let destinationURL = destinationURL(for: id)
        let temporaryDestination = directoryURL.appending(path: ".\(UUID().uuidString).m4a")
        try fileManager.copyItem(at: stagingURL, to: temporaryDestination)
        if fileManager.fileExists(atPath: destinationURL.path()) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryDestination, to: destinationURL)
        return try recordingFile(at: destinationURL)
    }

    public func fileURL(for entry: VoiceEntry) -> URL? {
        guard let fileName = entry.audioFileName,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent else {
            return nil
        }
        let url = directoryURL.appending(path: fileName)
        return fileManager.fileExists(atPath: url.path()) ? url : nil
    }

    public func deleteRecording(for entry: VoiceEntry) throws {
        guard let fileName = entry.audioFileName,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent else {
            return
        }
        let url = directoryURL.appending(path: fileName)
        if fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
    }

    public func removeTemporaryRecording(at url: URL?) {
        guard let url, fileManager.fileExists(atPath: url.path()) else { return }
        try? fileManager.removeItem(at: url)
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func destinationURL(for id: UUID) -> URL {
        directoryURL.appending(path: "\(id.uuidString.lowercased()).m4a")
    }

    private func recordingFile(at url: URL) throws -> VoiceRecordingFile {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return VoiceRecordingFile(
            fileName: url.lastPathComponent,
            fileURL: url,
            byteCount: Int64(values.fileSize ?? 0)
        )
    }
}
