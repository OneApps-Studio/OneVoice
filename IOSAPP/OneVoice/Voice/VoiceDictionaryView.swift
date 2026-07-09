import SwiftUI

struct VoiceDictionaryView: View {
    let model: OneVoiceMobileModel
    @State private var spoken = ""
    @State private var written = ""

    var body: some View {
        List {
            Section {
                TextField("What OneVoice hears", text: $spoken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("What OneVoice should write", text: $written)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Add Replacement", systemImage: "plus.circle.fill") {
                    let source = spoken
                    let destination = written
                    spoken = ""
                    written = ""
                    Task { await model.saveReplacement(spoken: source, written: destination) }
                }
                .disabled(spoken.trimmingCharacters(in: .whitespaces).isEmpty || written.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Teach OneVoice a term")
            } footer: {
                Text("Example: “one voice” → “OneVoice”. Replacements are applied locally to every final transcript.")
            }

            Section("Your replacements") {
                if model.replacements.isEmpty {
                    Text("No custom terms yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.replacements) { replacement in
                        HStack {
                            Text(replacement.spoken)
                            Spacer()
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                            Text(replacement.written).fontWeight(.semibold)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await model.deleteReplacement(replacement) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Dictionary")
    }
}
