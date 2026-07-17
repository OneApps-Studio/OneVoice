import AppKit
import OneAppsShell
import SwiftUI

struct OneVoiceMacSettingsView: View {
    let model: OneVoiceMacModel
    private let catalog = try? OneAppsCatalog.bundled()

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

            NavigationStack {
                Form {
                    Section("OneVoice") {
                        HStack(spacing: 14) {
                            Image(nsImage: NSApplication.shared.applicationIconImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Record, transcribe, remember")
                                    .font(.headline)
                                Text("Version \(appVersion) (\(buildNumber))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section("One Apps Studio") {
                        Link("Product Page", destination: URL(string: "https://oneapps.studio/apps/onevoice")!)
                        Link("Support", destination: URL(string: "https://oneapps.studio/support")!)
                        Link("Privacy Policy", destination: URL(string: "https://oneapps.studio/privacy")!)
                        Link("Source Code", destination: URL(string: "https://github.com/OneApps-Studio/OneVoice")!)
                    }
                    if let catalog {
                        Section("More From One Apps") {
                            OneAppsCatalogLink(catalog: catalog, currentAppID: "onevoice")
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("About")
            }
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "4"
    }
}
