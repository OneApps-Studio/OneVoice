import SwiftUI

struct OneVoiceMacHomeView: View {
    enum Destination: String, CaseIterable, Identifiable {
        case history = "History"
        case dictionary = "Dictionary"
        case models = "Models"
        case setup = "Setup"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .history: "clock.arrow.circlepath"
            case .dictionary: "text.book.closed"
            case .models: "cpu"
            case .setup: "checkmark.shield"
            }
        }
    }

    let model: OneVoiceMacModel
    @State private var selection: Destination? = .history

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, selection: $selection) { destination in
                Label(destination.rawValue, systemImage: destination.icon)
            }
            .navigationTitle("OneVoice")
        } detail: {
            switch selection {
            case .history:
                HistoryView(model: model)
            case .dictionary:
                DictionaryView(model: model)
            case .models:
                ModelsView(model: model)
            case .setup:
                SetupView(model: model)
            case nil:
                ContentUnavailableView("Select a section", systemImage: "waveform")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let message = model.lastDeliveryMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
        .alert("OneVoice needs attention", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK") { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "")
        }
    }
}

private struct HistoryView: View {
    let model: OneVoiceMacModel
    @State private var query = ""

    var body: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView {
                    Label("Ready for dictation", systemImage: "waveform")
                } description: {
                    Text("Hold Fn or tap Right Command to speak into any text field.")
                } actions: {
                    Button("Start Dictation") { model.toggleDictation() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(model.history) { entry in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(entry.transcript)
                            .font(.body)
                            .textSelection(.enabled)
                        HStack {
                            Text(entry.createdAt, style: .relative)
                            Text("·")
                            Text(entry.duration, format: .number.precision(.fractionLength(1)))
                            Text("seconds")
                            Spacer()
                            Button("Copy", systemImage: "doc.on.doc") {
                                model.copyTranscript(entry)
                            }
                            .labelStyle(.iconOnly)
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await model.deleteHistory([entry]) }
                            }
                            .labelStyle(.iconOnly)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("History")
        .searchable(text: $query)
        .onChange(of: query) { _, value in
            Task { await model.refreshHistory(query: value) }
        }
        .toolbar {
            ToolbarItem {
                Button(dictationButtonTitle, systemImage: model.isRecording ? "stop.fill" : "mic.fill") {
                    model.toggleDictation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isFinishing)
            }
        }
    }

    private var dictationButtonTitle: String {
        if model.isStarting { return "Cancel" }
        if model.isRecording { return "Finish" }
        if model.isFinishing { return "Finishing…" }
        return "Dictate"
    }
}

private struct DictionaryView: View {
    let model: OneVoiceMacModel
    @State private var spoken = ""
    @State private var written = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Add a pronunciation correction") {
                    TextField("What OneVoice hears", text: $spoken)
                        .autocorrectionDisabled()
                    TextField("What OneVoice should write", text: $written)
                        .autocorrectionDisabled()
                    Button("Add Replacement") {
                        let source = spoken
                        let destination = written
                        spoken = ""
                        written = ""
                        Task { await model.saveReplacement(spoken: source, written: destination) }
                    }
                    .disabled(spoken.trimmingCharacters(in: .whitespaces).isEmpty || written.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: 210)

            List(model.replacements) { replacement in
                HStack {
                    Text(replacement.spoken)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Text(replacement.written)
                        .fontWeight(.medium)
                    Spacer()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        Task { await model.deleteReplacement(replacement) }
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .navigationTitle("Dictionary")
    }
}

private struct ModelsView: View {
    let model: OneVoiceMacModel

    var body: some View {
        Form {
            Section("Active engine") {
                LabeledContent {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } label: {
                    VStack(alignment: .leading) {
                        Text("Apple On-Device Speech")
                        Text("Live transcription · no audio leaves your device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("High-accuracy model") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Qwen3-ASR 0.6B")
                            .font(.headline)
                        Spacer()
                        Label(
                            model.qwenInstalled ? "Installed" : "Optional",
                            systemImage: model.qwenInstalled ? "checkmark.circle.fill" : "arrow.down.circle"
                        )
                        .foregroundStyle(model.qwenInstalled ? .green : .secondary)
                    }
                    Text("Optional downloadable final-pass recognition for Mandarin, dialects, English, and mixed-language speech.")
                        .foregroundStyle(.secondary)
                    if model.qwenIsDownloading {
                        ProgressView(value: model.qwenDownloadProgress) {
                            Text(model.qwenStatusText)
                        }
                    } else if model.qwenInstalled {
                        Toggle("Use Qwen for the accurate final pass", isOn: Bindable(model).useQwenFinalPass)
                        HStack {
                            Text("Apple Speech continues to provide the live preview. Qwen replaces only the final transcript.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Remove Model", role: .destructive) {
                                Task { await model.removeQwenModel() }
                            }
                        }
                    } else {
                        Button("Download Qwen3-ASR 0.6B") {
                            Task { await model.downloadQwenModel() }
                        }
                        .buttonStyle(.borderedProminent)
                        Text("About 0.7–1 GB. Downloaded once, then recognition works entirely offline.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Models")
    }
}

private struct SetupView: View {
    let model: OneVoiceMacModel

    var body: some View {
        let _ = model.permissionGeneration
        Form {
            Section("Global dictation") {
                permissionRow("Accessibility", granted: MacPermissions.hasAccessibility)
                permissionRow("Input Monitoring", granted: MacPermissions.hasInputMonitoring)
                permissionRow("Microphone", granted: MacPermissions.hasMicrophone)
                permissionRow("Speech Recognition", granted: MacPermissions.hasSpeechRecognition)
                Button("Grant Required Permissions") {
                    Task { await model.requestSystemPermissions() }
                }
                .buttonStyle(.borderedProminent)
                Button("Open Privacy & Security") { model.openPrivacySettings() }
            }
            Section("Keyboard") {
                LabeledContent("Push to talk", value: "Hold Fn")
                LabeledContent("Start / finish", value: "Tap Right Command")
                Text("For Fn push-to-talk, set System Settings → Keyboard → Press fn key to → Do Nothing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Launch OneVoice at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Setup")
    }

    private func permissionRow(_ title: String, granted: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(granted ? "Granted" : "Required", systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
        }
    }
}
