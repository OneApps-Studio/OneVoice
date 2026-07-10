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
                Label("Audio and transcripts stay on this device", systemImage: "lock.shield.fill")
                Text("OneVoice only connects when you request the optional Qwen model. Apple may separately download and manage on-device speech assets. OneVoice has no account or analytics SDK.")
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
                Link("Source Code", destination: URL(string: "https://github.com/One-Apps-Studio/OneVoice")!)
            }

            Section {
                Button("Show Onboarding Again") {
                    hasCompletedOnboarding = false
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView(model: .shared)
    }
}
