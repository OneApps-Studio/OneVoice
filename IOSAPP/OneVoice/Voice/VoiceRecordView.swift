import OneVoiceCore
import SwiftUI
import UniformTypeIdentifiers

struct VoiceRecordView: View {
    let model: OneVoiceMobileModel
    @Environment(\.oneAppTheme) private var theme
    @State private var isChoosingFile = false
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            OnePageBackground()
            ScrollView {
                VStack(spacing: 24) {
                    Label("Private · On-device", systemImage: "lock.shield.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.primaryAccentSoftFill, in: Capsule())

                    VStack(spacing: 12) {
                        Group {
                            if model.isRecording {
                                Text(model.currentDuration.formattedDuration)
                            } else {
                                Text("Ready")
                            }
                        }
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        VoiceActivityBars(isActive: model.isRecording)
                            .frame(height: 46)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if model.isRecording {
                        Label(
                            "Recording continues when you lock your screen or use another app.",
                            systemImage: "lock.open.display"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            if model.isRecording { await model.finishRecording() }
                            else { await model.startRecording() }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(model.isRecording ? theme.danger : theme.buttonPrimaryFill)
                                .frame(width: 138, height: 138)
                                .shadow(color: (model.isRecording ? theme.danger : theme.primaryAccent).opacity(0.26), radius: 24, y: 12)
                            if model.isStarting {
                                ProgressView()
                                    .controlSize(.large)
                                    .tint(.white)
                            } else {
                                Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .disabled(!model.isReady || model.isStarting || model.isFinishing)
                    .accessibilityIdentifier("record-button")
                    .accessibilityLabel(model.isRecording ? Text("Finish recording") : Text("Start recording"))

                    MediaImportCard(
                        model: model,
                        isChoosingFile: $isChoosingFile,
                        isDropTargeted: $isDropTargeted
                    )

                    if model.isRecording || model.isFinishing {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                if model.isFinishing {
                                    Label("Creating final transcript", systemImage: "captions.bubble.fill")
                                        .font(.headline)
                                } else {
                                    Label("Live transcript", systemImage: "captions.bubble.fill")
                                        .font(.headline)
                                }
                                Spacer()
                                if model.isFinishing { ProgressView() }
                            }
                            Group {
                                if model.liveTranscript.isEmpty {
                                    Text("Start speaking…")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(verbatim: model.liveTranscript)
                                }
                            }
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                            .textSelection(.enabled)
                        }
                        .padding(18)
                        .oneCard()
                    } else if let entry = model.latestEntry {
                        LatestTranscriptCard(model: model, entry: entry)
                    } else {
                        VStack(spacing: 12) {
                            Text("Tap the microphone and speak naturally.")
                                .font(.headline)
                            Text("OneVoice saves the recording, creates a searchable transcript automatically, and syncs both through your private iCloud library by default.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .oneCard()
                    }

                    HStack {
                        Label("Live", systemImage: "bolt.fill")
                        Text("Apple Speech")
                        Spacer()
                        Image(systemName: "arrow.right")
                        if model.qwenInstalled && model.useQwenFinalPass {
                            Text("Qwen final")
                        } else {
                            Text("Apple final")
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, OneStyle.screenHorizontalPadding)
                .padding(.vertical, 24)
                .padding(.bottom, 90)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("OneVoice")
        .toolbar {
            if model.isRecording {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", role: .destructive) { Task { await model.cancelRecording() } }
                }
            }
        }
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.importMedia(at: url)
            } else if case let .failure(error) = result {
                model.lastError = error.localizedDescription
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.importMedia(at: url)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    private var statusText: LocalizedStringResource {
        if model.isStarting { return "Preparing private recognition…" }
        if model.isFinishing { return model.qwenInstalled && model.useQwenFinalPass ? "Running accurate offline final pass…" : "Finalizing on device…" }
        if model.isRecording { return "Recording and transcribing on this device" }
        return model.qwenInstalled && model.useQwenFinalPass ? "Apple live · Qwen accurate final" : "Apple on-device recognition"
    }
}

private struct MediaImportCard: View {
    let model: OneVoiceMobileModel
    @Binding var isChoosingFile: Bool
    @Binding var isDropTargeted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transcribe audio or video", systemImage: "waveform.badge.magnifyingglass")
                .font(.headline)
            if model.isImportingMedia {
                ProgressView(value: model.mediaImportProgress) {
                    Text(model.mediaImportFileName)
                }
                if !model.liveTranscript.isEmpty {
                    Text(model.liveTranscript)
                        .textSelection(.enabled)
                }
                Button("Cancel", role: .destructive) { model.cancelMediaImport() }
            } else {
                Text("Choose an audio or video file. It is processed on this device and is never saved by OneVoice.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Choose Audio or Video", systemImage: "plus") { isChoosingFile = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .oneCard()
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: OneStyle.cardRadius)
                    .stroke(themeColor, style: StrokeStyle(lineWidth: 2, dash: [7]))
            }
        }
    }

    private var themeColor: Color { .accentColor }
}

private struct VoiceActivityBars: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !isActive)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 4
            HStack(alignment: .center, spacing: 5) {
                ForEach(0..<17, id: \.self) { index in
                    let wave = abs(sin(phase + Double(index) * 0.72))
                    Capsule()
                        .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 4, height: isActive ? 10 + wave * 34 : 8)
                }
            }
        }
    }
}

private struct LatestTranscriptCard: View {
    let model: OneVoiceMobileModel
    let entry: VoiceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Recording and transcript saved", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                if entry.engineIdentifier.contains("qwen") {
                    Text("Qwen final")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Apple final")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(verbatim: entry.oneVoiceDisplayTitle)
                .font(.headline)
            Text(entry.transcript)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if model.audioURL(for: entry) != nil {
                    Button(
                        model.playingEntryID == entry.id ? "Stop" : "Play",
                        systemImage: model.playingEntryID == entry.id ? "stop.fill" : "play.fill"
                    ) {
                        Task { await model.togglePlayback(entry) }
                    }
                }
                Button("Copy", systemImage: "doc.on.doc") { model.copy(entry) }
                Spacer()
                if let audioURL = model.audioURL(for: entry) {
                    ShareLink(item: audioURL) {
                        Label("Share Audio", systemImage: "square.and.arrow.up")
                    }
                } else {
                    ShareLink(item: entry.transcript) {
                        Label("Share Text", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .oneCard()
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        let total = max(0, Int(self.rounded(.down)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
