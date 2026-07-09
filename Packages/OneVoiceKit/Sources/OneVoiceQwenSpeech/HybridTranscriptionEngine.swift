import Foundation
import OneVoiceCore

public actor HybridTranscriptionEngine: TranscriptionEngine {
    public nonisolated let identifier = "apple-live-qwen3-final"

    private let liveEngine: any TranscriptionEngine
    private let qwenManager: QwenModelManager
    private var useQwenFinalPass: Bool
    private var samples: [Float] = []
    private var language: String?
    private var qwenEligible = true
    private var resampler = StreamingLinearResampler(outputRate: 16_000)
    private let maximumQwenSampleCount = 16_000 * 30 * 60

    public init(
        liveEngine: any TranscriptionEngine,
        qwenManager: QwenModelManager,
        useQwenFinalPass: Bool = true
    ) {
        self.liveEngine = liveEngine
        self.qwenManager = qwenManager
        self.useQwenFinalPass = useQwenFinalPass
    }

    public func setUseQwenFinalPass(_ enabled: Bool) {
        useQwenFinalPass = enabled
    }

    public func start(
        localeIdentifier: String
    ) async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        samples = []
        qwenEligible = true
        resampler.reset()
        language = Self.qwenLanguage(for: localeIdentifier)
        return try await liveEngine.start(localeIdentifier: localeIdentifier)
    }

    public func append(_ frame: AudioFrame) async throws {
        if qwenEligible {
            samples.append(contentsOf: resampler.process(frame.samples, sourceRate: frame.sampleRate))
            if samples.count > maximumQwenSampleCount {
                samples = []
                qwenEligible = false
            }
        }
        try await liveEngine.append(frame)
    }

    public func finish() async throws -> Transcript {
        let liveTranscript = try await liveEngine.finish()
        defer {
            samples = []
            qwenEligible = true
            resampler.reset()
        }
        guard useQwenFinalPass,
              qwenEligible,
              await qwenManager.isInstalled(),
              !samples.isEmpty else {
            return liveTranscript
        }

        let bufferedSamples = samples
        do {
            let qwenText = try await qwenManager.transcribe(
                audio: bufferedSamples,
                sampleRate: 16_000,
                language: language
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !qwenText.isEmpty else { return liveTranscript }
            return Transcript(text: qwenText, engineIdentifier: identifier)
        } catch {
            return liveTranscript
        }
    }

    public func cancel() async {
        samples = []
        qwenEligible = true
        resampler.reset()
        await liveEngine.cancel()
    }

    private static func qwenLanguage(for localeIdentifier: String) -> String? {
        let language = Locale(identifier: localeIdentifier).language.languageCode?.identifier
        return switch language {
        case "zh": "Chinese"
        case "en": "English"
        case "ja": "Japanese"
        default: nil
        }
    }

}

private struct StreamingLinearResampler: Sendable {
    let outputRate: Double
    private var sourceRate: Double?
    private var previousSample: Float?
    private var nextPosition = 0.0

    init(outputRate: Double) {
        self.outputRate = outputRate
    }

    mutating func reset() {
        sourceRate = nil
        previousSample = nil
        nextPosition = 0
    }

    mutating func process(_ input: [Float], sourceRate: Double) -> [Float] {
        guard !input.isEmpty, sourceRate > 0, outputRate > 0 else { return [] }
        if let existingRate = self.sourceRate, abs(existingRate - sourceRate) > 0.1 {
            reset()
        }
        self.sourceRate = sourceRate
        if abs(sourceRate - outputRate) <= 0.1 {
            previousSample = input.last
            return input
        }

        var combined = input
        if let previousSample {
            combined.insert(previousSample, at: 0)
        }
        guard combined.count > 1 else {
            previousSample = combined.last
            return []
        }

        let step = sourceRate / outputRate
        var output: [Float] = []
        output.reserveCapacity(Int(ceil(Double(input.count) / step)) + 1)
        var position = previousSample == nil ? 0 : nextPosition
        let lastPosition = Double(combined.count - 1)
        while position < lastPosition {
            let lower = Int(position)
            let upper = min(lower + 1, combined.count - 1)
            let fraction = Float(position - Double(lower))
            output.append(combined[lower] + (combined[upper] - combined[lower]) * fraction)
            position += step
        }
        previousSample = combined.last
        nextPosition = position - lastPosition
        return output
    }
}
