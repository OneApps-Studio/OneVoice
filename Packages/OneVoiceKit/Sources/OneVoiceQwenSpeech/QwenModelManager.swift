import CryptoKit
import Foundation
import Qwen3ASR

public actor QwenModelManager {
    public static let modelIdentifier = "aufklarer/Qwen3-ASR-0.6B-MLX-4bit"
    public static let modelRevision = "bc441bd1e4295c1f42d9879f056049a925b6e013"

    public enum ManagerError: LocalizedError, Sendable {
        case notInstalled
        case invalidDownload(String)

        public var errorDescription: String? {
            switch self {
            case .notInstalled:
                "Qwen3-ASR has not been downloaded yet."
            case let .invalidDownload(file):
                "The downloaded Qwen3-ASR file is incomplete or invalid: \(file)"
            }
        }
    }

    private struct ModelFile: Sendable {
        let name: String
        let size: Int64
        let sha256: String
    }

    private static let modelFiles: [ModelFile] = [
        .init(
            name: "config.json",
            size: 7_187,
            sha256: "923618cf5ca452fda0253a6be5c1a17f94a2e4851d3b98beb45848565587bd72"
        ),
        .init(
            name: "merges.txt",
            size: 1_671_853,
            sha256: "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5"
        ),
        .init(
            name: "model.safetensors",
            size: 708_236_945,
            sha256: "70c7e67e588062adce4f10796e47ad42ead51c6671eda61a0987eae38ca95ddf"
        ),
        .init(
            name: "model.safetensors.index.json",
            size: 71_814,
            sha256: "e3bb80ef0fd42a5be07b04e90c97d60460bbde8af3531e0bfe9100a61404d81a"
        ),
        .init(
            name: "tokenizer_config.json",
            size: 12_487,
            sha256: "4942d005604266809309cabc9f4e9cb89ce855d59b14681fdc0e1cc62ea26c4c"
        ),
        .init(
            name: "vocab.json",
            size: 2_776_833,
            sha256: "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"
        ),
    ]

    public let cacheDirectory: URL
    private var model: Qwen3ASRModel?

    public init(cacheDirectory: URL? = nil) {
        self.cacheDirectory = cacheDirectory ?? Self.defaultCacheDirectory()
    }

    public func isInstalled() -> Bool {
        Self.modelFiles.allSatisfy { file in
            fileSize(at: cacheDirectory.appending(path: file.name)) == file.size
        }
    }

    public func download(
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        try FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var modelDirectory = cacheDirectory
        try? modelDirectory.setResourceValues(resourceValues)

        let totalBytes = Self.modelFiles.reduce(Int64(0)) { $0 + $1.size }
        var completedBytes: Int64 = 0

        for file in Self.modelFiles {
            try Task.checkCancellation()
            let destination = cacheDirectory.appending(path: file.name)
            if fileSize(at: destination) == file.size {
                completedBytes += file.size
                continue
            }

            let encodedName = file.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                ?? file.name
            guard let url = URL(
                string: "https://huggingface.co/\(Self.modelIdentifier)/resolve/\(Self.modelRevision)/\(encodedName)"
            ) else {
                throw ManagerError.invalidDownload(file.name)
            }

            let bytesBeforeFile = completedBytes
            progress(
                Double(completedBytes) / Double(totalBytes),
                "Downloading \(file.name)…"
            )
            let downloader = ResumableFileDownload(
                source: url,
                destination: destination,
                expectedBytes: file.size
            ) { downloadedBytes in
                let fraction = min(
                    1,
                    Double(bytesBeforeFile + downloadedBytes) / Double(totalBytes)
                )
                progress(fraction, "Downloading Qwen3-ASR… \(Int(fraction * 100))%")
            }
            try await downloader.start()
            guard fileSize(at: destination) == file.size else {
                throw ManagerError.invalidDownload(file.name)
            }
            completedBytes += file.size
        }

        progress(0.995, "Verifying model…")
        try verifyInstalledFiles(removingInvalidFile: true)

        progress(0.997, "Loading model…")
        let loaded = try await Qwen3ASRModel.fromPretrained(
            modelId: Self.modelIdentifier,
            cacheDir: cacheDirectory,
            offlineMode: true
        )
        model?.unload()
        loaded.unload()
        model = nil
        progress(1, "Installed and ready")
    }

    public func transcribe(
        audio: [Float],
        sampleRate: Int = 16_000,
        language: String?
    ) async throws -> String {
        if model == nil {
            guard isInstalled() else { throw ManagerError.notInstalled }
            try verifyInstalledFiles(removingInvalidFile: false)
            model = try await Qwen3ASRModel.fromPretrained(
                modelId: Self.modelIdentifier,
                cacheDir: cacheDirectory,
                offlineMode: true
            )
        }
        guard let model else { throw ManagerError.notInstalled }
        return model.transcribe(
            audio: audio,
            sampleRate: sampleRate,
            language: language,
            maxTokens: 448
        )
    }

    public func unload() {
        model?.unload()
        model = nil
    }

    public func removeDownloadedModel() throws {
        unload()
        guard FileManager.default.fileExists(atPath: cacheDirectory.path) else { return }
        try FileManager.default.removeItem(at: cacheDirectory)
    }

    private func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }

    private func verifyInstalledFiles(removingInvalidFile: Bool) throws {
        for file in Self.modelFiles {
            let url = cacheDirectory.appending(path: file.name)
            guard fileSize(at: url) == file.size,
                  try Self.sha256(of: url) == file.sha256 else {
                if removingInvalidFile {
                    try? FileManager.default.removeItem(at: url)
                }
                throw ManagerError.invalidDownload(file.name)
            }
        }
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            guard let data = try handle.read(upToCount: 4 * 1_024 * 1_024),
                  !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func defaultCacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appending(path: "Library/Application Support")
        return base
            .appending(path: "OneVoice", directoryHint: .isDirectory)
            .appending(path: "Models", directoryHint: .isDirectory)
            .appending(path: "Qwen3-ASR-0.6B-MLX-4bit", directoryHint: .isDirectory)
    }
}

private final class ResumableFileDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let source: URL
    private let destination: URL
    private let expectedBytes: Int64
    private let progress: @Sendable (Int64) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?
    private var completed = false

    private var resumeDataURL: URL {
        destination.appendingPathExtension("resume")
    }

    init(
        source: URL,
        destination: URL,
        expectedBytes: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) {
        self.source = source
        self.destination = destination
        self.expectedBytes = expectedBytes
        self.progress = progress
    }

    func start() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock {
                    self.continuation = continuation
                }
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 90
                configuration.timeoutIntervalForResource = 3_600
                configuration.waitsForConnectivity = true
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session

                let task: URLSessionDownloadTask
                if let resumeData = try? Data(contentsOf: resumeDataURL), !resumeData.isEmpty {
                    task = session.downloadTask(withResumeData: resumeData)
                } else {
                    task = session.downloadTask(with: source)
                }
                task.resume()
            }
        } onCancel: {
            self.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progress(totalBytesWritten)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse,
                  200..<300 ~= response.statusCode else {
                throw URLError(.badServerResponse)
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
            guard size == expectedBytes else {
                throw NSError(
                    domain: "OneVoice.QwenDownload",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Downloaded \(destination.lastPathComponent) has \(size) bytes; expected \(expectedBytes).",
                    ]
                )
            }

            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let staging = destination.appendingPathExtension("download")
            try? FileManager.default.removeItem(at: staging)
            try FileManager.default.copyItem(at: location, to: staging)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: staging, to: destination)
            try? FileManager.default.removeItem(at: resumeDataURL)
            complete(with: .success(()))
        } catch {
            complete(with: .failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        if let resumeData = nsError.userInfo["NSURLSessionDownloadTaskResumeData"] as? Data {
            try? resumeData.write(to: resumeDataURL, options: .atomic)
        }
        complete(with: .failure(error))
    }

    private func cancel() {
        lock.withLock {
            guard !completed else { return }
            session?.getAllTasks { tasks in
                for case let task as URLSessionDownloadTask in tasks {
                    task.cancel { resumeData in
                        if let resumeData {
                            try? resumeData.write(to: self.resumeDataURL, options: .atomic)
                        }
                    }
                }
            }
        }
    }

    private func complete(with result: Result<Void, Error>) {
        let continuation: CheckedContinuation<Void, Error>? = lock.withLock {
            guard !completed else { return nil }
            completed = true
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }
        session?.finishTasksAndInvalidate()
        session = nil
        continuation?.resume(with: result)
    }
}
