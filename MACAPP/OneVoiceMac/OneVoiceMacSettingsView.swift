import SwiftUI

struct OneVoiceMacSettingsView: View {
    let model: OneVoiceMacModel

    var body: some View {
        TabView {
            Form {
                LabeledContent("Push to talk", value: "Hold Fn")
                LabeledContent("Toggle dictation", value: "Tap Right Command")
                Picker("Recognition language", selection: Bindable(model).localeIdentifier) {
                    Text("简体中文").tag("zh-Hans")
                    Text("English (US)").tag("en-US")
                    Text("日本語").tag("ja-JP")
                }
                Toggle("Launch \(OneVoiceMacIdentity.displayName) at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }
            .padding(24)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Text("\(OneVoiceMacIdentity.displayName) processes speech locally and has no analytics or OneVoice server. Voice-note audio from iPhone or iPad, transcripts, and dictionary replacements can sync through your private Apple iCloud account. Mac quick-dictation audio is never saved.")
            }
            .padding(24)
            .tabItem {
                Label("Privacy", systemImage: "hand.raised")
            }
        }
    }
}
