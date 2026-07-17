import SwiftUI
import UniformTypeIdentifiers
import OneVoiceCore

struct OneVoiceMacHomeView: View {
    enum Destination: String, CaseIterable, Identifiable {
        case transcribe = "Transcribe File"
        case history = "Library"
        case dictionary = "Dictionary"
        case models = "Models"
        case setup = "Setup"

        var id: String { rawValue }
        var title: LocalizedStringResource {
            switch self {
            case .transcribe: "Transcribe File"
            case .history: "Library"
            case .dictionary: "Dictionary"
            case .models: "Models"
            case .setup: "Setup"
            }
        }
        var icon: String {
            switch self {
            case .transcribe: "waveform.badge.magnifyingglass"
            case .history: "clock.arrow.circlepath"
            case .dictionary: "text.book.closed"
            case .models: "cpu"
            case .setup: "checkmark.shield"
            }
        }
    }

    let model: OneVoiceMacModel
    @State private var selection: Destination? = .transcribe

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, selection: $selection) { destination in
                Label(destination.title, systemImage: destination.icon)
                    .tag(destination)
            }
            .navigationTitle(OneVoiceMacIdentity.displayName)
        } detail: {
            switch selection {
            case .transcribe:
                MediaTranscriptionView(model: model)
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

private struct MediaTranscriptionView: View {
    let model: OneVoiceMacModel
    @State private var isChoosingFile = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("Transcribe audio or video")
                    .font(.title2.bold())
                Text("Drop a media file here. OneVoice reads its audio track locally and saves only the transcript.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if model.isImportingMedia {
                VStack(spacing: 10) {
                    ProgressView(value: model.mediaImportProgress) {
                        Text(model.mediaImportFileName)
                    }
                    if model.liveTranscript.isEmpty {
                        Text("Preparing private recognition…")
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                    } else {
                        Text(model.liveTranscript)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                            .textSelection(.enabled)
                    }
                    Button("Cancel", role: .destructive) { model.cancelMediaImport() }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            } else {
                Button("Choose Audio or Video", systemImage: "plus") {
                    isChoosingFile = true
                }
                .buttonStyle(.borderedProminent)
            }

            if let entry = model.latestImportedEntry {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Transcript saved to History", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text(entry.transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    Button("Copy", systemImage: "doc.on.doc") { model.copyTranscript(entry) }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
            Spacer(minLength: 24)
        }
        .padding(32)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .navigationTitle("Transcribe File")
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
}

private struct HistoryView: View {
    let model: OneVoiceMacModel
    @State private var query = ""

    var body: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView {
                    Label("No recordings or transcripts yet", systemImage: "waveform")
                } description: {
                    Text("Voice notes from iPhone appear here through private iCloud sync. Mac dictation transcripts are saved here too.")
                } actions: {
                    Button("Start Dictation") { model.toggleDictation() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(model.history) { entry in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(entry.displayTitle)
                            .font(.headline)
                        if !entry.transcript.isEmpty, entry.transcript != entry.displayTitle {
                            Text(entry.transcript)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(5)
                        } else if entry.transcript.isEmpty {
                            Text("Audio saved · transcript unavailable")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text(entry.createdAt, style: .relative)
                            Text("·")
                            Text(entry.duration, format: .number.precision(.fractionLength(1)))
                            Text("seconds")
                            Spacer()
                            if model.audioURL(for: entry) != nil {
                                Button(
                                    isPlaying(entry) ? "Pause" : "Play",
                                    systemImage: isPlaying(entry) ? "pause.fill" : "play.fill"
                                ) {
                                    Task { await model.togglePlayback(entry) }
                                }
                                .labelStyle(.iconOnly)
                            }
                            if !entry.transcript.isEmpty {
                                Button("Copy", systemImage: "doc.on.doc") {
                                    model.copyTranscript(entry)
                                }
                                .labelStyle(.iconOnly)
                            }
                            if let audioURL = model.audioURL(for: entry) {
                                ShareLink(item: audioURL) {
                                    Label("Share Audio", systemImage: "square.and.arrow.up")
                                }
                                .labelStyle(.iconOnly)
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await model.deleteHistory([entry]) }
                            }
                            .labelStyle(.iconOnly)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if model.playingEntryID == entry.id {
                            VStack(spacing: 7) {
                                Slider(
                                    value: Binding(
                                        get: { model.playbackTime },
                                        set: { value in
                                            Task { await model.seekPlayback(to: value, entry: entry) }
                                        }
                                    ),
                                    in: 0...max(model.playbackDuration, 0.1)
                                )
                                HStack {
                                    Text(model.playbackTime.formattedMacPlaybackDuration)
                                    Spacer()
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
                                    }
                                    .accessibilityLabel(isPlaying(entry) ? "Pause" : "Play")
                                    Button {
                                        Task { await model.skipPlayback(by: 15, entry: entry) }
                                    } label: {
                                        Image(systemName: "goforward.15")
                                    }
                                    .accessibilityLabel("Forward 15 Seconds")
                                    Menu("\(Double(model.playbackRate).formatted())×") {
                                        ForEach([0.5, 1, 1.5, 2], id: \.self) { rate in
                                            Button("\(rate.formatted())×") {
                                                model.setPlaybackRate(Float(rate))
                                            }
                                        }
                                    }
                                    Text(model.playbackDuration.formattedMacPlaybackDuration)
                                }
                                .font(.caption.monospacedDigit())
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Library")
        .searchable(text: $query)
        .onChange(of: query) { _, value in
            Task { await model.refreshHistory(query: value) }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    model.toggleDictation()
                } label: {
                    Label {
                        Text(dictationButtonTitle)
                    } icon: {
                        Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isFinishing)
            }
        }
    }

    private var dictationButtonTitle: LocalizedStringResource {
        if model.isStarting { return "Cancel" }
        if model.isRecording { return "Finish" }
        if model.isFinishing { return "Finishing…" }
        return "Dictate"
    }

    private func isPlaying(_ entry: VoiceEntry) -> Bool {
        model.playingEntryID == entry.id && model.playbackIsActive
    }
}

private extension TimeInterval {
    var formattedMacPlaybackDuration: String {
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
                Picker("Hold to talk", selection: Bindable(model).pushToTalkKey) {
                    ForEach(GlobalHotkeyKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }
                Picker("Tap to start or finish", selection: Bindable(model).toggleKey) {
                    ForEach(GlobalHotkeyKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }
                if model.pushToTalkKey == .function || model.toggleKey == .function {
                    Text("When using Fn, set System Settings → Keyboard → Press fn key to → Do Nothing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }
            Section("iCloud Sync") {
                Toggle("Sync recordings, transcripts, and dictionary", isOn: Binding(
                    get: { model.iCloudSyncEnabled },
                    set: { model.setICloudSyncEnabled($0) }
                ))
                LabeledContent("Status") {
                    Text(cloudStatusText)
                }
                Button("Sync Now") { model.refreshCloudSync() }
                    .disabled(!model.iCloudSyncEnabled)
                Text("Voice-note audio, transcripts, and dictionary replacements sync through your private iCloud database. Quick-dictation audio, imported media, and downloaded models never sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Setup")
    }

    private var cloudStatusText: LocalizedStringResource {
        switch model.iCloudSyncStatus {
        case .disabled: "Off"
        case .syncing: "Syncing…"
        case .synced: "Synced"
        case .unavailable: "iCloud unavailable"
        case .failed: "Sync error"
        }
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
