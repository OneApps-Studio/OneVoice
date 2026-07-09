import AVFoundation
import OneVoiceCore

final class MacMicrophoneCapture: @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case noInputChannels
        case configurationChanged

        var errorDescription: String? {
            switch self {
            case .noInputChannels: "No microphone input is available."
            case .configurationChanged: "The microphone configuration changed while recording."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var running = false
    private var configurationObserver: NSObjectProtocol?

    func start(
        frameHandler: @escaping @Sendable (AudioFrame) -> Void,
        errorHandler: @escaping @Sendable (Error) -> Void
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !running else { return }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw CaptureError.noInputChannels }

        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            guard let channels = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            guard frameCount > 0, channelCount > 0 else { return }

            var samples = [Float](repeating: 0, count: frameCount)
            for channel in 0..<channelCount {
                let source = channels[channel]
                for index in 0..<frameCount {
                    samples[index] += source[index] / Float(channelCount)
                }
            }
            frameHandler(AudioFrame(samples: samples, sampleRate: buffer.format.sampleRate))
        }

        engine.prepare()
        do {
            try engine.start()
            running = true
            configurationObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: engine,
                queue: nil
            ) { _ in
                errorHandler(CaptureError.configurationChanged)
            }
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        running = false
    }
}
