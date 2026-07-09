@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import OneVoiceCore
import Speech

public actor AppleSpeechTranscriptionEngine: TranscriptionEngine {
    private final class ConversionInput: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
        var wasSupplied = false

        init(buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }
    }

    public enum EngineError: LocalizedError, Sendable {
        case unavailable
        case unsupportedLocale(String)
        case noCompatibleAudioFormat
        case notRunning
        case audioBufferCreationFailed
        case audioConversionFailed(String)

        public var errorDescription: String? {
            switch self {
            case .unavailable:
                "Apple on-device speech recognition is unavailable on this device."
            case let .unsupportedLocale(locale):
                "The language \(locale) is not supported by Apple on-device speech recognition."
            case .noCompatibleAudioFormat:
                "No compatible audio format is available for speech recognition."
            case .notRunning:
                "No speech recognition session is running."
            case .audioBufferCreationFailed:
                "The microphone audio could not be prepared for speech recognition."
            case let .audioConversionFailed(message):
                "The microphone audio could not be converted for speech recognition: \(message)"
            }
        }
    }

    public nonisolated let identifier = "apple-speech-on-device"

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var audioContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var updateContinuation: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation?
    private var analysisTask: Task<CMTime?, Error>?
    private var resultsTask: Task<Void, Error>?
    private var analyzerFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var converterSourceFormat: AVAudioFormat?
    private var finalizedText = ""
    private var volatileText = ""

    public init() {}

    public func start(
        localeIdentifier: String
    ) async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        if analyzer != nil {
            await cancel()
        }

        let requestedLocale = Locale(identifier: localeIdentifier)
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw EngineError.unsupportedLocale(localeIdentifier)
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        try await installAssetsIfNeeded(for: transcriber, locale: locale)

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        ) else {
            throw EngineError.noCompatibleAudioFormat
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: format)

        let (inputs, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let updates = AsyncThrowingStream<TranscriptionUpdate, Error> { continuation in
            self.updateContinuation = continuation
        }

        self.analyzer = analyzer
        self.transcriber = transcriber
        analyzerFormat = format
        audioContinuation = inputContinuation
        finalizedText = ""
        volatileText = ""

        resultsTask = Task { [weak self, transcriber] in
            do {
                for try await result in transcriber.results {
                    try Task.checkCancellation()
                    await self?.receive(
                        text: String(result.text.characters),
                        isFinal: result.isFinal
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                await self?.fail(error)
                throw error
            }
        }

        analysisTask = Task { [analyzer, inputs] in
            try await analyzer.analyzeSequence(inputs)
        }

        return updates
    }

    public func append(_ frame: AudioFrame) async throws {
        guard let continuation = audioContinuation,
              let analyzerFormat else {
            throw EngineError.notRunning
        }

        let sourceFormat = try sourceFormat(for: frame)
        if converter == nil || converterSourceFormat != sourceFormat {
            guard let newConverter = AVAudioConverter(from: sourceFormat, to: analyzerFormat) else {
                throw EngineError.audioConversionFailed("Unsupported source format.")
            }
            converter = newConverter
            converterSourceFormat = sourceFormat
        }

        guard let sourceBuffer = makeSourceBuffer(from: frame, format: sourceFormat),
              let converter else {
            throw EngineError.audioBufferCreationFailed
        }

        for input in try convert(sourceBuffer, using: converter, endOfStream: false) {
            continuation.yield(input)
        }
    }

    public func finish() async throws -> Transcript {
        guard let analyzer else { throw EngineError.notRunning }

        if let converter, let continuation = audioContinuation {
            for input in try flush(converter) {
                continuation.yield(input)
            }
        }
        audioContinuation?.finish()
        audioContinuation = nil

        let lastSampleTime = try await analysisTask?.value
        if let lastSampleTime {
            try await analyzer.finalizeAndFinish(through: lastSampleTime)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        try await resultsTask?.value

        let text = combinedTranscript
        updateContinuation?.yield(.init(text: text, isFinal: true))
        updateContinuation?.finish()
        clearSession()
        return Transcript(text: text, engineIdentifier: identifier)
    }

    public func cancel() async {
        audioContinuation?.finish()
        audioContinuation = nil
        analysisTask?.cancel()
        resultsTask?.cancel()
        await analyzer?.cancelAndFinishNow()
        updateContinuation?.finish(throwing: CancellationError())
        clearSession()
    }

    private func installAssetsIfNeeded(
        for transcriber: SpeechTranscriber,
        locale: Locale
    ) async throws {
        let modules: [any SpeechModule] = [transcriber]
        switch await AssetInventory.status(forModules: modules) {
        case .installed:
            return
        case .unsupported:
            throw EngineError.unsupportedLocale(locale.identifier)
        case .supported, .downloading:
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                try await request.downloadAndInstall()
            }
            _ = try? await AssetInventory.reserve(locale: locale)
        @unknown default:
            throw EngineError.unavailable
        }
    }

    private func receive(text: String, isFinal: Bool) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        if isFinal {
            if !finalizedText.isEmpty, needsSeparator(between: finalizedText, and: cleaned) {
                finalizedText.append(" ")
            }
            finalizedText.append(cleaned)
            volatileText = ""
        } else {
            volatileText = cleaned
        }
        updateContinuation?.yield(.init(text: combinedTranscript, isFinal: isFinal))
    }

    private func fail(_ error: Error) {
        updateContinuation?.finish(throwing: error)
    }

    private var combinedTranscript: String {
        guard !volatileText.isEmpty else { return finalizedText }
        guard !finalizedText.isEmpty else { return volatileText }
        return needsSeparator(between: finalizedText, and: volatileText)
            ? finalizedText + " " + volatileText
            : finalizedText + volatileText
    }

    private func needsSeparator(between lhs: String, and rhs: String) -> Bool {
        guard let last = lhs.unicodeScalars.last, let first = rhs.unicodeScalars.first else {
            return false
        }
        return CharacterSet.alphanumerics.contains(last)
            && CharacterSet.alphanumerics.contains(first)
    }

    private func sourceFormat(for frame: AudioFrame) throws -> AVAudioFormat {
        guard frame.sampleRate > 0,
              let format = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: frame.sampleRate,
                  channels: 1,
                  interleaved: false
              ) else {
            throw EngineError.audioBufferCreationFailed
        }
        return format
    }

    private func makeSourceBuffer(from frame: AudioFrame, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !frame.samples.isEmpty,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: format,
                  frameCapacity: AVAudioFrameCount(frame.samples.count)
              ), let channel = buffer.floatChannelData?.pointee else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frame.samples.count)
        channel.update(from: frame.samples, count: frame.samples.count)
        return buffer
    }

    private func convert(
        _ sourceBuffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        endOfStream: Bool
    ) throws -> [AnalyzerInput] {
        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let outputCapacity = max(
            1,
            AVAudioFrameCount(ceil(Double(sourceBuffer.frameLength) * ratio) + 64)
        )
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: outputCapacity
        ) else {
            throw EngineError.audioBufferCreationFailed
        }

        let conversionInput = ConversionInput(buffer: sourceBuffer)
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
            if !conversionInput.wasSupplied {
                conversionInput.wasSupplied = true
                inputStatus.pointee = .haveData
                return conversionInput.buffer
            }
            inputStatus.pointee = endOfStream ? .endOfStream : .noDataNow
            return nil
        }

        if status == .error || conversionError != nil {
            throw EngineError.audioConversionFailed(
                conversionError?.localizedDescription ?? "Unknown converter error."
            )
        }
        guard outputBuffer.frameLength > 0 else { return [] }
        return [AnalyzerInput(buffer: outputBuffer)]
    }

    private func flush(_ converter: AVAudioConverter) throws -> [AnalyzerInput] {
        var inputs: [AnalyzerInput] = []
        while true {
            let outputCapacity = max(1, converter.outputFormat.sampleRate > 0 ? 4096 : 1)
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: converter.outputFormat,
                frameCapacity: AVAudioFrameCount(outputCapacity)
            ) else {
                throw EngineError.audioBufferCreationFailed
            }

            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
                inputStatus.pointee = .endOfStream
                return nil
            }
            if status == .error || conversionError != nil {
                throw EngineError.audioConversionFailed(
                    conversionError?.localizedDescription ?? "Unknown converter error."
                )
            }
            if outputBuffer.frameLength > 0 {
                inputs.append(AnalyzerInput(buffer: outputBuffer))
            }
            if status == .endOfStream || outputBuffer.frameLength == 0 {
                break
            }
        }
        return inputs
    }

    private func clearSession() {
        analyzer = nil
        transcriber = nil
        audioContinuation = nil
        updateContinuation = nil
        analysisTask = nil
        resultsTask = nil
        analyzerFormat = nil
        converter = nil
        converterSourceFormat = nil
        finalizedText = ""
        volatileText = ""
    }
}
