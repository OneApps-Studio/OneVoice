@preconcurrency import AVFoundation
import OneVoiceCore

final class MobileMicrophoneCapture: @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case noInputChannels
        case interrupted
        case inputRouteLost

        var errorDescription: String? {
            switch self {
            case .noInputChannels: "No microphone input is available."
            case .interrupted: "Recording was interrupted by another audio session."
            case .inputRouteLost: "The active microphone was disconnected."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var running = false
    private var observers: [NSObjectProtocol] = []
    private var recordingFile: AVAudioFile?

    func start(
        recordingURL: URL,
        frameHandler: @escaping @Sendable (AudioFrame) -> Void,
        errorHandler: @escaping @Sendable (Error) -> Void
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !running else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw CaptureError.noInputChannels }
        try FileManager.default.createDirectory(
            at: recordingURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: recordingURL.path) {
            try FileManager.default.removeItem(at: recordingURL)
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVEncoderBitRateKey: 64_000 * Int(format.channelCount),
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recordingFile = try AVAudioFile(
            forWriting: recordingURL,
            settings: settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        self.recordingFile = recordingFile
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            do {
                try recordingFile.write(from: buffer)
            } catch {
                errorHandler(error)
                return
            }
            guard let channels = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            guard frameCount > 0, channelCount > 0 else { return }
            var samples = [Float](repeating: 0, count: frameCount)
            for channel in 0..<channelCount {
                for index in 0..<frameCount {
                    samples[index] += channels[channel][index] / Float(channelCount)
                }
            }
            frameHandler(AudioFrame(samples: samples, sampleRate: buffer.format.sampleRate))
        }

        engine.prepare()
        do {
            try engine.start()
            running = true
            installObservers(errorHandler: errorHandler)
        } catch {
            input.removeTap(onBus: 0)
            self.recordingFile = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        recordingFile = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        removeObservers()
        running = false
    }

    private func installObservers(errorHandler: @escaping @Sendable (Error) -> Void) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { notification in
            guard let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawValue) == .began else {
                return
            }
            errorHandler(CaptureError.interrupted)
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { notification in
            guard let rawValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: rawValue) == .oldDeviceUnavailable else {
                return
            }
            errorHandler(CaptureError.inputRouteLost)
        })
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }
}
