import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct MainTabView: View {
    let model: OneVoiceMobileModel
    @AppStorage(AppStorageKeys.appAppearance) private var appAppearanceValue = AppAppearance.system.rawValue
    @AppStorage(AppStorageKeys.appTheme) private var appThemeValue = OneAppTheme.defaultTheme.rawValue
    @Environment(\.oneAppTheme) private var theme
    @State private var selectedTab: MainTab = .initial

    var body: some View {
        SystemMainTabContent(model: model, selectedTab: $selectedTab)
        .tint(theme.navigationTint)
        .onAppear {
            configureTabBarAppearance()
        }
        .onChange(of: appAppearanceValue) {
            configureTabBarAppearance()
        }
        .onChange(of: appThemeValue) {
            configureTabBarAppearance()
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

    private func configureTabBarAppearance() {
        #if canImport(UIKit)
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26 else { return }

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = theme.uiBackground.withAlphaComponent(0.92)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.stackedLayoutAppearance.normal.iconColor = theme.uiSecondaryText
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: theme.uiSecondaryText]
        appearance.stackedLayoutAppearance.selected.iconColor = theme.uiAccent
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: theme.uiAccent]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }
}
