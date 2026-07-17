import OneVoiceCore
import SwiftUI

struct VoiceRecordingDetailView: View {
    let model: OneVoiceMobileModel
    let entryID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.oneAppTheme) private var theme
    @State private var waveformSamples: [Double] = []
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isConfirmingDelete = false

    var body: some View {
        ZStack {
            OnePageBackground()

            if let entry {
                ScrollView {
                    VStack(spacing: OneStyle.sectionSpacing) {
                        recordingHeader(entry)
                        playerCard(entry)
                        transcriptCard(entry)
                    }
                    .padding(.horizontal, OneStyle.screenHorizontalPadding)
                    .padding(.top, OneStyle.rootContentTopSpacing)
                    .padding(.bottom, 48)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .task(id: model.audioURL(for: entry)) {
                    guard let url = model.audioURL(for: entry) else {
                        waveformSamples = []
                        return
                    }
                    waveformSamples = await AudioWaveformSampler.samples(for: url)
                }
            } else {
                ContentUnavailableView("Recording unavailable", systemImage: "waveform.slash")
            }
        }
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let entry {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await model.toggleFavorite(entry) }
                    } label: {
                        Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityLabel(entry.isFavorite ? "Unfavorite" : "Favorite")

                    Menu {
                        if let audioURL = model.audioURL(for: entry) {
                            ShareLink(item: audioURL) {
                                Label("Share Audio", systemImage: "square.and.arrow.up")
                            }
                        }
                        if !entry.transcript.isEmpty {
                            ShareLink(item: entry.transcript) {
                                Label("Share Text", systemImage: "doc.text")
                            }
                        }
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More Actions")
                }
            }
        }
        .alert("Rename Recording", isPresented: $isEditingTitle) {
            TextField("Title", text: $editedTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard let entry else { return }
                Task { await model.updateTitle(editedTitle, for: entry) }
            }
        }
        .confirmationDialog(
            "Delete this recording?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Recording", role: .destructive) {
                guard let entry else { return }
                Task {
                    await model.delete(entry)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The audio and transcript will be removed from this device and your private iCloud library.")
        }
    }

    private var entry: VoiceEntry? {
        model.entry(id: entryID)
    }

    private func recordingHeader(_ entry: VoiceEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: entry.oneVoiceDisplayTitle)
                        .font(.title2.bold())
                    Text(entry.createdAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button {
                    editedTitle = entry.oneVoiceDisplayTitle
                    isEditingTitle = true
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 38, height: 38)
                        .background(theme.primaryAccentSoftFill, in: Circle())
                }
                .accessibilityLabel("Rename Recording")
            }

            HStack(spacing: 14) {
                Label(entry.duration.formattedVoiceDuration, systemImage: "clock")
                Label(recognitionLabel(entry), systemImage: "waveform.badge.magnifyingglass")
                if entry.source == .importedFile {
                    Label("Imported", systemImage: "square.and.arrow.down")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .oneCard()
    }

    private func playerCard(_ entry: VoiceEntry) -> some View {
        VStack(spacing: 16) {
            RecordingWaveformView(
                samples: waveformSamples,
                progress: playbackProgress(for: entry),
                accent: theme.primaryAccent
            )
            .frame(height: 82)

            Slider(value: playbackBinding(for: entry), in: 0...max(playbackDuration(for: entry), 0.1))
                .disabled(model.audioURL(for: entry) == nil)
                .accessibilityLabel("Playback Position")

            HStack {
                Text(playbackTime(for: entry).formattedVoiceDuration)
                Spacer()
                Text(playbackDuration(for: entry).formattedVoiceDuration)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            HStack(spacing: 28) {
                Button {
                    Task { await model.skipPlayback(by: -15, entry: entry) }
                } label: {
                    Image(systemName: "gobackward.15")
                }
                .accessibilityLabel("Back 15 Seconds")

                Button {
                    Task { await model.togglePlayback(entry) }
                } label: {
                    Image(systemName: isPlaying(entry) ? "pause.fill" : "play.fill")
                        .font(.title2.bold())
                        .foregroundStyle(theme.buttonPrimaryText)
                        .frame(width: 64, height: 64)
                        .background(theme.buttonPrimaryFill, in: Circle())
                }
                .disabled(model.audioURL(for: entry) == nil)
                .accessibilityLabel(isPlaying(entry) ? "Pause" : "Play")

                Button {
                    Task { await model.skipPlayback(by: 15, entry: entry) }
                } label: {
                    Image(systemName: "goforward.15")
                }
                .accessibilityLabel("Forward 15 Seconds")
            }
            .font(.title3)

            Menu {
                ForEach([0.5, 1, 1.5, 2], id: \.self) { rate in
                    Button {
                        model.setPlaybackRate(Float(rate))
                    } label: {
                        if model.playbackRate == Float(rate) {
                            Label("\(rate.formatted())×", systemImage: "checkmark")
                        } else {
                            Text("\(rate.formatted())×")
                        }
                    }
                }
            } label: {
                Label("Playback Speed", systemImage: "speedometer")
                Spacer()
                Text("\(Double(model.playbackRate).formatted())×")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .oneCard()
    }

    private func transcriptCard(_ entry: VoiceEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Transcript", systemImage: "text.quote")
                    .font(.headline)
                Spacer()
                if !entry.transcript.isEmpty {
                    Button("Copy", systemImage: "doc.on.doc") {
                        model.copy(entry)
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            if entry.transcript.isEmpty {
                Text("A transcript is not available for this recording.")
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.transcript)
                    .font(.body)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .oneCard()
    }

    private func recognitionLabel(_ entry: VoiceEntry) -> LocalizedStringResource {
        entry.engineIdentifier.contains("qwen") ? "Accurate Offline" : "Apple On-Device"
    }

    private func isPlaying(_ entry: VoiceEntry) -> Bool {
        model.playingEntryID == entry.id && model.playbackIsActive
    }

    private func playbackTime(for entry: VoiceEntry) -> TimeInterval {
        model.playingEntryID == entry.id ? model.playbackTime : 0
    }

    private func playbackDuration(for entry: VoiceEntry) -> TimeInterval {
        model.playingEntryID == entry.id && model.playbackDuration > 0
            ? model.playbackDuration
            : entry.duration
    }

    private func playbackProgress(for entry: VoiceEntry) -> Double {
        let duration = playbackDuration(for: entry)
        guard duration > 0 else { return 0 }
        return min(max(playbackTime(for: entry) / duration, 0), 1)
    }

    private func playbackBinding(for entry: VoiceEntry) -> Binding<Double> {
        Binding(
            get: { playbackTime(for: entry) },
            set: { value in
                Task { await model.seekPlayback(to: value, entry: entry) }
            }
        )
    }
}

private struct RecordingWaveformView: View {
    let samples: [Double]
    let progress: Double
    let accent: Color

    var body: some View {
        Group {
            if samples.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { proxy in
                    let spacing: CGFloat = 2
                    let width = max(1, (proxy.size.width - CGFloat(samples.count - 1) * spacing) / CGFloat(samples.count))

                    HStack(alignment: .center, spacing: spacing) {
                        ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                            Capsule()
                                .fill(Double(index) / Double(max(samples.count - 1, 1)) <= progress
                                      ? accent
                                      : accent.opacity(0.34))
                                .frame(width: width, height: max(5, proxy.size.height * sample))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
