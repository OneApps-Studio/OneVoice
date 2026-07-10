@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import OneVoiceCore

public actor MediaAudioReader {
    public enum ReaderError: LocalizedError, Sendable {
        case noAudioTrack
        case unsupportedAudio
        case couldNotStart(String)
        case couldNotRead(String)

        public var errorDescription: String? {
            switch self {
            case .noAudioTrack:
                "This file does not contain an audio track."
            case .unsupportedAudio:
                "The audio track could not be decoded."
            case let .couldNotStart(message):
                "The file could not be opened for transcription: \(message)"
            case let .couldNotRead(message):
                "The file could not be read for transcription: \(message)"
            }
        }
    }

    public init() {}

    @discardableResult
    public func read(
        url: URL,
        onFrame: @Sendable (AudioFrame) async throws -> Void,
        onProgress: @Sendable (Double) async -> Void = { _ in }
    ) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw ReaderError.noAudioTrack }

        let duration = try await asset.load(.duration)
        let durationSeconds = duration.isNumeric ? max(0, duration.seconds) : 0
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: tracks[0],
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ReaderError.unsupportedAudio }
        reader.add(output)
        guard reader.startReading() else {
            throw ReaderError.couldNotStart(reader.error?.localizedDescription ?? "Unknown media error.")
        }

        await onProgress(0)
        while let sampleBuffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let samples = try samples(from: sampleBuffer)
            if !samples.isEmpty {
                try await onFrame(AudioFrame(samples: samples, sampleRate: 16_000))
            }

            if durationSeconds > 0 {
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let seconds = presentationTime.isNumeric ? max(0, presentationTime.seconds) : 0
                await onProgress(min(0.995, seconds / durationSeconds))
            }
            CMSampleBufferInvalidate(sampleBuffer)
        }

        switch reader.status {
        case .completed:
            await onProgress(1)
            return durationSeconds
        case .cancelled:
            throw CancellationError()
        case .failed:
            throw ReaderError.couldNotRead(reader.error?.localizedDescription ?? "Unknown media error.")
        default:
            throw ReaderError.couldNotRead("The decoder stopped before the file was complete.")
        }
    }

    private func samples(from sampleBuffer: CMSampleBuffer) throws -> [Float] {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            throw ReaderError.unsupportedAudio
        }
        let byteCount = CMBlockBufferGetDataLength(blockBuffer)
        guard byteCount > 0, byteCount.isMultiple(of: MemoryLayout<Float>.size) else {
            return []
        }

        var samples = [Float](repeating: 0, count: byteCount / MemoryLayout<Float>.size)
        let status = samples.withUnsafeMutableBytes { destination in
            guard let address = destination.baseAddress else { return kCMBlockBufferBadCustomBlockSourceErr }
            return CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: byteCount,
                destination: address
            )
        }
        guard status == kCMBlockBufferNoErr else {
            throw ReaderError.couldNotRead("The decoded audio buffer was invalid (\(status)).")
        }
        return samples
    }
}
