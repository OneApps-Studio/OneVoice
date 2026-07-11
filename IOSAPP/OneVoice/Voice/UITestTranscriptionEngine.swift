#if DEBUG
import Foundation
import OneVoiceCore

actor UITestTranscriptionEngine: TranscriptionEngine {
    nonisolated let identifier = "onevoice-ui-test-speech"

    private var continuation: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation?
    private var didEmitUpdate = false

    func start(
        localeIdentifier: String
    ) async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        didEmitUpdate = false
        return AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func append(_ frame: AudioFrame) async throws {
        guard !didEmitUpdate else { return }
        didEmitUpdate = true
        continuation?.yield(.init(text: "Background recording test", isFinal: false))
    }

    func finish() async throws -> Transcript {
        let text = "Background recording test"
        continuation?.yield(.init(text: text, isFinal: true))
        continuation?.finish()
        continuation = nil
        return Transcript(text: text, engineIdentifier: identifier)
    }

    func cancel() async {
        continuation?.finish(throwing: CancellationError())
        continuation = nil
    }
}
#endif
