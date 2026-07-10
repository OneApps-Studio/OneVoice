import AVFoundation
import Foundation
import OneVoiceAppleSpeech
import OneVoiceCore
import Testing

@Suite("Media audio reader")
struct MediaAudioReaderTests {
    @Test("Audio files are decoded to mono 16 kHz frames")
    func decodesAudioFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410))
            buffer.frameLength = 4_410
            let channel = try #require(buffer.floatChannelData?.pointee)
            for index in 0..<Int(buffer.frameLength) {
                channel[index] = sin(Float(index) * 0.04) * 0.2
            }
            try file.write(from: buffer)
        }

        let accumulator = FrameAccumulator()
        let reader = MediaAudioReader()
        let duration = try await reader.read(url: url) { frame in
            await accumulator.append(frame)
        }

        #expect(duration > 0.09)
        #expect(await accumulator.sampleRate == 16_000)
        #expect(await accumulator.sampleCount > 1_000)
    }
}

private actor FrameAccumulator {
    private(set) var sampleRate = 0.0
    private(set) var sampleCount = 0

    func append(_ frame: AudioFrame) {
        sampleRate = frame.sampleRate
        sampleCount += frame.samples.count
    }
}
