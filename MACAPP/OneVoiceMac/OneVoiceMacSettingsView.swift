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
                Toggle("Launch OneVoice at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }
            .padding(24)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Text("OneVoice processes speech locally. Network access is only used when you explicitly download an offline model.")
            }
            .padding(24)
            .tabItem {
                Label("Privacy", systemImage: "hand.raised")
            }
        }
    }
}
