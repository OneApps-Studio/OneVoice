import OneVoiceCore
import SwiftUI

struct VoiceLibraryView: View {
    let model: OneVoiceMobileModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.oneAppTheme) private var theme
    @State private var query = ""
    @State private var isPresentingRecorder = false

    var body: some View {
        ZStack {
            OnePageBackground()

            ScrollView {
                LazyVStack(spacing: 14) {
                    recordAction

                    if model.history.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.history) { entry in
                            VoiceLibraryRow(model: model, entry: entry)
                        }
                    }
                }
                .padding(.horizontal, OneStyle.screenHorizontalPadding)
                .padding(.top, OneStyle.rootContentTopSpacing)
                .padding(.bottom, 112)
                .frame(maxWidth: OneStyle.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
            .refreshable { await model.refreshHistory(query: query) }
        }
        .navigationTitle("Recordings")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: "Search recordings")
        .onChange(of: query) { _, value in
            Task { await model.refreshHistory(query: value) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingRecorder = true
                } label: {
                    Label("New Recording", systemImage: "plus")
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingRecorder) {
            NavigationStack {
                VoiceRecordView(model: model)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { isPresentingRecorder = false }
                        }
                    }
            }
            .environment(\.oneAppTheme, theme)
        }
    }

    private var recordAction: some View {
        Button {
            isPresentingRecorder = true
        } label: {
            HStack(spacing: 14) {
                OneIconTile(
                    icon: model.isRecording ? "waveform" : "mic.fill",
                    tint: model.isRecording ? theme.danger : theme.primaryAccent,
                    size: 46,
                    cornerRadius: 14,
                    style: .solid
                )

                VStack(alignment: .leading, spacing: 3) {
                    if model.isRecording {
                        Text("Continue Recording")
                            .font(.headline)
                        Text(model.currentDuration.formattedVoiceDuration)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        Text("New Recording")
                            .font(.headline)
                        Text("Record and transcribe on this device")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .oneCard(isInteractive: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("new-recording-button")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            OneIconTile(
                icon: query.isEmpty ? "waveform" : "magnifyingglass",
                size: 58,
                cornerRadius: 17
            )
            if query.isEmpty {
                Text("No recordings yet")
                    .font(.title3.bold())
                Text("Your recordings and searchable transcripts will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No matches")
                    .font(.title3.bold())
                Text("Try another title or phrase from a transcript.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .oneCard()
    }
}

private struct VoiceLibraryRow: View {
    let model: OneVoiceMobileModel
    let entry: VoiceEntry

    @Environment(\.oneAppTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                VoiceRecordingDetailView(model: model, entryID: entry.id)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(verbatim: entry.oneVoiceDisplayTitle)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)

                            if !entry.transcript.isEmpty, entry.transcript != entry.oneVoiceDisplayTitle {
                                Text(entry.transcript)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            } else if entry.transcript.isEmpty {
                                Text("Audio saved · transcript unavailable")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer(minLength: 8)
                        if entry.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(theme.favorite)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 7) {
                        Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                        Text("·")
                        Text(entry.duration.formattedVoiceDuration)
                        if entry.source == .importedFile {
                            Text("·")
                            Label("Imported", systemImage: "square.and.arrow.down")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            OneDivider()

            HStack(spacing: 20) {
                if model.audioURL(for: entry) != nil {
                    Button {
                        Task { await model.togglePlayback(entry) }
                    } label: {
                        Label(playbackLabel, systemImage: playbackIcon)
                    }
                    .accessibilityIdentifier("play-recording-\(entry.id.uuidString.lowercased())")
                }

                if !entry.transcript.isEmpty {
                    Button {
                        model.copy(entry)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }

                Spacer()

                Menu {
                    Button {
                        Task { await model.toggleFavorite(entry) }
                    } label: {
                        Label(entry.isFavorite ? "Unfavorite" : "Favorite", systemImage: entry.isFavorite ? "star.slash" : "star")
                    }
                    if let audioURL = model.audioURL(for: entry) {
                        ShareLink(item: audioURL) {
                            Label("Share Audio", systemImage: "square.and.arrow.up")
                        }
                    } else if !entry.transcript.isEmpty {
                        ShareLink(item: entry.transcript) {
                            Label("Share Text", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button(role: .destructive) {
                        Task { await model.delete(entry) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More Actions")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.primaryAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .oneCard()
        .accessibilityIdentifier("recording-\(entry.id.uuidString.lowercased())")
    }

    private var isThisEntryPlaying: Bool {
        model.playingEntryID == entry.id && model.playbackIsActive
    }

    private var playbackLabel: LocalizedStringResource {
        isThisEntryPlaying ? "Pause" : "Play"
    }

    private var playbackIcon: String {
        isThisEntryPlaying ? "pause.fill" : "play.fill"
    }
}

extension TimeInterval {
    var formattedVoiceDuration: String {
        guard isFinite else { return "00:00" }
        let total = max(0, Int(rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}

extension VoiceEntry {
    var oneVoiceDisplayTitle: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        let firstLine = transcript.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        if !firstLine.isEmpty {
            return String(firstLine.prefix(80))
        }
        return String(localized: "Untitled Recording", locale: AppLanguage.current.locale)
    }
}
