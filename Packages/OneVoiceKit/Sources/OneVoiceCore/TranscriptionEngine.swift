import Foundation

public struct AudioFrame: Sendable, Equatable {
    public let samples: [Float]
    public let sampleRate: Double

    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }
}

public struct TranscriptionUpdate: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool

    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

public struct Transcript: Sendable, Equatable {
    public let text: String
    public let engineIdentifier: String

    public init(text: String, engineIdentifier: String) {
        self.text = text
        self.engineIdentifier = engineIdentifier
    }
}

public protocol TranscriptionEngine: Sendable {
    var identifier: String { get }

    func start(
        localeIdentifier: String
    ) async throws -> AsyncThrowingStream<TranscriptionUpdate, Error>

    func append(_ frame: AudioFrame) async throws
    func finish() async throws -> Transcript
    func cancel() async
}
