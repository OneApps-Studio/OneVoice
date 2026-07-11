import SwiftUI

struct OneVoiceMacSettingsView: View {
    let model: OneVoiceMacModel

    var body: some View {
        TabView {
            Form {
                Section("Language") {
                    Picker("App language", selection: Bindable(model).appLanguage) {
                        ForEach(MacAppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    Picker("Recognition language", selection: Bindable(model).localeIdentifier) {
                        Text("简体中文").tag("zh-Hans")
                        Text("English (US)").tag("en-US")
                        Text("日本語").tag("ja-JP")
                    }
                }
                Section("Global shortcuts") {
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
                    Text("The two shortcuts must be different. OneVoice automatically keeps them from conflicting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Restore Default Shortcuts") {
                        model.pushToTalkKey = .defaultPushToTalk
                        model.toggleKey = .defaultToggle
                    }
                }
                Section("Startup") {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                }
            }
            .padding(24)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Text("OneVoice processes speech locally and has no analytics or OneVoice server. Voice-note audio from iPhone, transcripts, and dictionary replacements can sync through your private Apple iCloud account. Mac quick-dictation audio is never saved.")
            }
            .padding(24)
            .tabItem {
                Label("Privacy", systemImage: "hand.raised")
            }
        }
    }
}
