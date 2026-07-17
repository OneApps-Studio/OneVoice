import SwiftUI

struct SystemMainTabContent: View {
    let model: OneVoiceMobileModel
    @Binding var selectedTab: MainTab

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Recordings", systemImage: "waveform", value: MainTab.recordings) {
                NavigationStack {
                    VoiceLibraryView(model: model)
                }
                .accessibilityIdentifier("main-tab-recordings")
            }

            Tab("Dictionary", systemImage: "text.book.closed.fill", value: MainTab.dictionary) {
                NavigationStack {
                    VoiceDictionaryView(model: model)
                }
                .accessibilityIdentifier("main-tab-dictionary")
            }

            Tab("Settings", systemImage: "gearshape", value: MainTab.settings) {
                NavigationStack {
                    SettingsView(model: model)
                }
                .accessibilityIdentifier("main-tab-settings")
            }
        }
    }
}
