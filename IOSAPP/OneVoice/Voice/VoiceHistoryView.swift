import OneVoiceCore
import SwiftUI

struct VoiceHistoryView: View {
    let model: OneVoiceMobileModel
    @State private var query = ""

    var body: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView {
                    if query.isEmpty {
                        Label("No voice notes yet", systemImage: "waveform")
                    } else {
                        Label("No matches", systemImage: "waveform")
                    }
                } description: {
                    if query.isEmpty {
                        Text("Your private transcripts will appear here.")
                    } else {
                        Text("Try a different search.")
                    }
                }
            } else {
                List(model.history) { entry in
                    VoiceHistoryRow(model: model, entry: entry)
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await model.toggleFavorite(entry) }
                            } label: {
                                if entry.isFavorite {
                                    Label("Unfavorite", systemImage: "star.fill")
                                } else {
                                    Label("Favorite", systemImage: "star.fill")
                                }
                            }
                            .tint(.yellow)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await model.delete(entry) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("History")
        .searchable(text: $query, prompt: "Search transcripts")
        .onChange(of: query) { _, value in
            Task { await model.refreshHistory(query: value) }
        }
        .refreshable { await model.refreshHistory(query: query) }
    }
}

private struct VoiceHistoryRow: View {
    let model: OneVoiceMobileModel
    let entry: VoiceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(entry.transcript)
                    .lineLimit(5)
                Spacer(minLength: 8)
                if entry.isFavorite {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
            }
            HStack {
                Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                Text("·")
                Text(entry.duration.formattedDuration)
                Spacer()
                Button { model.copy(entry) } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                ShareLink(item: entry.transcript) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        let total = max(0, Int(self.rounded(.down)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
