import OneVoiceCore
import SwiftUI

struct VoiceDictionaryView: View {
    let model: OneVoiceMobileModel
    @State private var spoken = ""
    @State private var written = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.oneAppTheme) private var theme

    var body: some View {
        ZStack {
            OnePageBackground()

            ScrollView {
                OneSectionStack(spacing: OneStyle.sectionSpacing) {
                    addReplacementSection
                    replacementsSection
                }
                .padding(.horizontal, OneStyle.screenHorizontalPadding)
                .padding(.top, OneStyle.rootContentTopSpacing)
                .padding(.bottom, 112)
                .frame(maxWidth: OneStyle.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.large)
    }

    private var addReplacementSection: some View {
        OneSection(title: "Teach OneVoice a term") {
            VStack(spacing: 0) {
                TextField("What OneVoice hears", text: $spoken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(16)

                OneDivider()

                TextField("What OneVoice should write", text: $written)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(16)

                OneDivider()

                Button {
                    let source = spoken
                    let destination = written
                    spoken = ""
                    written = ""
                    Task { await model.saveReplacement(spoken: source, written: destination) }
                } label: {
                    Label("Add Replacement", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(theme.primaryAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .buttonStyle(.plain)
                .disabled(!canSaveReplacement)
            }

            OneDivider()

            Text("Example: “one voice” → “OneVoice”. Replacements are applied locally to every final transcript.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(16)
        }
    }

    private var replacementsSection: some View {
        OneSection(title: "Your replacements") {
            if model.replacements.isEmpty {
                HStack(spacing: 12) {
                    OneIconTile(icon: "text.book.closed", size: 40, cornerRadius: 12)
                    Text("No custom terms yet")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.replacements.enumerated()), id: \.element.id) { index, replacement in
                        replacementRow(replacement)
                        if index < model.replacements.count - 1 {
                            OneDivider()
                        }
                    }
                }
            }
        }
    }

    private var canSaveReplacement: Bool {
        !spoken.trimmingCharacters(in: .whitespaces).isEmpty
            && !written.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func replacementRow(_ replacement: DictionaryReplacement) -> some View {
        HStack(spacing: 10) {
            Text(replacement.spoken)
                .lineLimit(2)
            Spacer(minLength: 8)
            Image(systemName: "arrow.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
            Text(replacement.written)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)

            Button(role: .destructive) {
                Task { await model.deleteReplacement(replacement) }
            } label: {
                Image(systemName: "trash")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
