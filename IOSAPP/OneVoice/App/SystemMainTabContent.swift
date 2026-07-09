import SwiftUI

struct SystemMainTabContent: View {
    let model: OneVoiceMobileModel
    @Binding var selectedTab: MainTab

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Record", systemImage: "mic.fill", value: MainTab.record) {
                NavigationStack {
                    VoiceRecordView(model: model)
                }
                .accessibilityIdentifier("main-tab-record")
            }

            Tab("History", systemImage: "clock.arrow.circlepath", value: MainTab.history) {
                NavigationStack {
                    VoiceHistoryView(model: model)
                }
                .accessibilityIdentifier("main-tab-history")
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
