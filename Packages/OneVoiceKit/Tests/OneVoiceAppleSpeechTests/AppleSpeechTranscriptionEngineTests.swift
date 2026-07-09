import AVFoundation
import Foundation
import OneVoiceAppleSpeech
import OneVoiceCore
import Testing

@Suite("Apple on-device speech", .serialized)
struct AppleSpeechTranscriptionEngineTests {
    @Test("A local audio file is transcribed without a network service", .timeLimit(.minutes(3)))
    func transcribesLocalAudioFile() async throws {
        guard let fixturePath = ProcessInfo.processInfo.environment["ONEVOICE_SPEECH_FIXTURE"],
              !fixturePath.isEmpty else {
            return
        }
        let fixture = URL(fileURLWithPath: fixturePath)
        guard FileManager.default.fileExists(atPath: fixture.path) else {
            return
        }

        let engine = AppleSpeechTranscriptionEngine()
        let updates = try await engine.start(localeIdentifier: "en-US")
        let updateTask = Task { () -> [TranscriptionUpdate] in
            var received: [TranscriptionUpdate] = []
            do {
                for try await update in updates {
                    received.append(update)
                }
            } catch {}
            return received
        }

        let file = try AVAudioFile(forReading: fixture)
        let format = file.processingFormat
        while file.framePosition < file.length {
            let count = min(1_024, AVAudioFrameCount(file.length - file.framePosition))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else {
                Issue.record("Could not allocate an audio buffer")
                return
            }
            try file.read(into: buffer, frameCount: count)
            guard let channels = buffer.floatChannelData else {
                Issue.record("Fixture must decode to floating-point PCM")
                return
            }
            let samples = Array(UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
            try await engine.append(AudioFrame(samples: samples, sampleRate: format.sampleRate))
        }

        let transcript = try await engine.finish().text.lowercased()
        _ = await updateTask.value
        #expect(transcript.contains("onevoice") || transcript.contains("one voice"))
        #expect(transcript.contains("offline"))
    }
}
