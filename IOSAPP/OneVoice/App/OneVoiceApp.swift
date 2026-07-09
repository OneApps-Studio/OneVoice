import SwiftUI

@main
struct OneVoiceApp: App {
    @AppStorage(AppStorageKeys.appLanguage) private var appLanguageValue = AppLanguage.system.rawValue
    @AppStorage(AppStorageKeys.appAppearance) private var appAppearanceValue = AppAppearance.system.rawValue
    @AppStorage(AppStorageKeys.appTheme) private var appThemeValue = OneAppTheme.defaultTheme.rawValue

    @State private var model = OneVoiceMobileModel.shared

    init() {
        #if DEBUG
        DebugLaunchArguments.applyIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .environment(\.locale, selectedLanguage.locale)
                .environment(\.oneAppTheme, selectedTheme)
                .preferredColorScheme(selectedAppearance.colorScheme)
                .tint(selectedTheme.navigationTint)
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageValue) ?? .system
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceValue) ?? .system
    }

    private var selectedTheme: OneAppTheme {
        OneAppTheme(rawValue: appThemeValue) ?? .defaultTheme
    }
}
