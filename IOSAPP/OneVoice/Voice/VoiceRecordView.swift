import OneVoiceCore
import SwiftUI

struct VoiceRecordView: View {
    let model: OneVoiceMobileModel
    @Environment(\.oneAppTheme) private var theme

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
                            Text("Your final transcript is copied automatically, saved to History, and ready to paste anywhere.")
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
    }

    private var statusText: LocalizedStringResource {
        if model.isStarting { return "Preparing private recognition…" }
        if model.isFinishing { return model.qwenInstalled && model.useQwenFinalPass ? "Running accurate offline final pass…" : "Finalizing on device…" }
        if model.isRecording { return "Listening on this device" }
        return model.qwenInstalled && model.useQwenFinalPass ? "Apple live · Qwen accurate final" : "Apple on-device recognition"
    }
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
                Label("Copied and saved", systemImage: "checkmark.circle.fill")
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
            Text(entry.transcript)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button("Copy", systemImage: "doc.on.doc") { model.copy(entry) }
                Spacer()
                ShareLink(item: entry.transcript) {
                    Label("Share", systemImage: "square.and.arrow.up")
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
