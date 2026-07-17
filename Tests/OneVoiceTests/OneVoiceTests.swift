import AVFoundation
import Testing
import OneVoiceCore
import UIKit
@testable import OneVoice

@MainActor
@Test("Completed mobile transcripts are copied to the system pasteboard")
func copiesCompletedTranscript() async {
    let insertion = MobileClipboardInsertion()
    let outcome = await insertion.insert("OneVoice offline test", into: TextInsertionTarget())

    #expect(outcome == .copiedToClipboard)
    #expect(UIPasteboard.general.string == "OneVoice offline test")
}

@Test("Waveform samples come from recorded audio amplitudes")
func samplesRecordedAudioWaveform() async throws {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "onevoice-waveform-\(UUID().uuidString).caf")
    defer { try? FileManager.default.removeItem(at: url) }

    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let frameCount: AVAudioFrameCount = 4_410
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
    buffer.frameLength = frameCount
    let channel = try #require(buffer.floatChannelData?[0])
    for frame in 0..<Int(frameCount) {
        let envelope = Float(frame) / Float(frameCount)
        channel[frame] = sin(Float(frame) * 0.05) * envelope
    }
    try file.write(from: buffer)

    let samples = await AudioWaveformSampler.samples(for: url, count: 32)

    #expect(samples.count == 32)
    #expect(samples.allSatisfy { $0 >= 0.08 && $0 <= 1 })
    #expect((samples.max() ?? 0) > 0.9)
    #expect((samples.last ?? 0) > (samples.first ?? 1))
}

@Test("Playback duration formatting supports hour-long recordings")
func formatsPlaybackDuration() {
    #expect(TimeInterval(0).formattedVoiceDuration == "00:00")
    #expect(TimeInterval(65).formattedVoiceDuration == "01:05")
    #expect(TimeInterval(3_661).formattedVoiceDuration == "1:01:01")
}
