import AVFoundation
import Foundation

enum AudioWaveformSampler {
    static func samples(for url: URL, count: Int = 96) async -> [Double] {
        let sampleCount = max(count, 1)
        return await Task.detached(priority: .utility) {
            (try? readSamples(from: url, count: sampleCount)) ?? []
        }.value
    }

    private static func readSamples(from url: URL, count: Int) throws -> [Double] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = max(AVAudioFramePosition(1), file.length)
        let channelCount = max(1, Int(format.channelCount))
        let bufferCapacity: AVAudioFrameCount = 4_096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferCapacity) else {
            return []
        }

        var peaks = Array(repeating: Float.zero, count: count)
        var frameOffset: AVAudioFramePosition = 0

        while frameOffset < totalFrames {
            buffer.frameLength = 0
            try file.read(into: buffer, frameCount: bufferCapacity)
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0, let channels = buffer.floatChannelData else { break }

            for frameIndex in 0..<frameLength {
                let absoluteFrame = frameOffset + AVAudioFramePosition(frameIndex)
                let bucket = min(count - 1, Int(absoluteFrame * AVAudioFramePosition(count) / totalFrames))
                var peak = Float.zero
                for channel in 0..<channelCount {
                    peak = max(peak, abs(channels[channel][frameIndex]))
                }
                peaks[bucket] = max(peaks[bucket], peak)
            }
            frameOffset += AVAudioFramePosition(frameLength)
        }

        let maximum = max(peaks.max() ?? 0, 0.000_1)
        return peaks.map { peak in
            max(0.08, min(1, Double(sqrt(peak / maximum))))
        }
    }
}
