import SwiftUI

struct SettingsView: View {
    let model: OneVoiceMobileModel
    @AppStorage(AppStorageKeys.appLanguage) private var appLanguageValue = AppLanguage.system.rawValue
    @AppStorage(AppStorageKeys.appAppearance) private var appAppearanceValue = AppAppearance.system.rawValue
    @AppStorage(AppStorageKeys.appTheme) private var appThemeValue = OneAppTheme.defaultTheme.rawValue
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = true

    var body: some View {
        Form {
            Section("Recognition") {
                Picker("Language", selection: Bindable(model).localeIdentifier) {
                    Text("简体中文").tag("zh-Hans")
                    Text("English (US)").tag("en-US")
                    Text("日本語").tag("ja-JP")
                }
                LabeledContent("Live engine", value: "Apple On-Device Speech")
            }

            QwenModelSettingsSection(model: model)

            Section("iCloud Sync") {
                Toggle(
                    "Sync recordings, transcripts, and dictionary",
                    isOn: Binding(
                        get: { model.iCloudSyncEnabled },
                        set: { model.setICloudSyncEnabled($0) }
                    )
                )
                LabeledContent("Status") {
                    Text(iCloudStatusText)
                }
                Button("Sync Now") { model.refreshCloudSync() }
                    .disabled(!model.iCloudSyncEnabled)
                Text("Voice-note audio, transcripts, and dictionary replacements sync through your private iCloud database. Imported media and downloaded models never sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                NavigationLink("Theme & Appearance") {
                    SettingsThemeAppearanceView(
                        appAppearanceValue: $appAppearanceValue,
                        appThemeValue: $appThemeValue
                    )
                }
                NavigationLink("App Language") {
                    SettingsLanguageView(appLanguageValue: $appLanguageValue)
                }
            }

            Section("Privacy") {
                Label("Your recordings stay private", systemImage: "lock.shield.fill")
                Text("OneVoice has no account, analytics SDK, or OneVoice server. Voice notes are stored locally and, when iCloud Sync is on, mirrored with their transcripts through your private Apple iCloud account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent(
                    "Version",
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                )
                Link("Qwen3-ASR", destination: URL(string: "https://github.com/QwenLM/Qwen3-ASR")!)
                Link("speech-swift", destination: URL(string: "https://github.com/soniqo/speech-swift")!)
                Link("Source Code", destination: URL(string: "https://github.com/OneApps-Studio/OneVoice")!)
            }

            Section {
                Button("Show Onboarding Again") {
                    hasCompletedOnboarding = false
                }
            }
        }
        .navigationTitle("Settings")
    }

    private var iCloudStatusText: LocalizedStringResource {
        switch model.iCloudSyncStatus {
        case .disabled: "Off"
        case .syncing: "Syncing…"
        case .synced: "Synced"
        case .unavailable: "iCloud unavailable"
        case .failed: "Sync error"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(model: .shared)
    }
}
