import Foundation

#if DEBUG
enum DebugLaunchArguments {
    static func applyIfNeeded() {
        let environment = debugValues()
        guard environment["ONEVOICE_UI_TEST"] == "1" else { return }

        let defaults = UserDefaults.standard
        [
            AppStorageKeys.hasCompletedOnboarding,
            AppStorageKeys.appLanguage,
            AppStorageKeys.appAppearance,
            AppStorageKeys.appTheme,
        ].forEach(defaults.removeObject)

        if environment["ONEVOICE_RESET_DATA"] == "1",
           let support = FileManager.default.urls(
               for: .applicationSupportDirectory,
               in: .userDomainMask
           ).first {
            try? FileManager.default.removeItem(at: support.appending(path: "OneVoice"))
        }

        if let value = environment["ONEVOICE_HAS_COMPLETED_ONBOARDING"] {
            defaults.set(value == "1", forKey: AppStorageKeys.hasCompletedOnboarding)
        }

        if let value = environment["ONEVOICE_APP_LANGUAGE"] {
            defaults.set(value, forKey: AppStorageKeys.appLanguage)
        }

        if let value = environment["ONEVOICE_APP_APPEARANCE"] {
            defaults.set(value, forKey: AppStorageKeys.appAppearance)
        }

        if let value = environment["ONEVOICE_APP_THEME"] {
            defaults.set(value, forKey: AppStorageKeys.appTheme)
        }

    }

    private static func debugValues() -> [String: String] {
        var values = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments

        for index in arguments.indices where arguments[index].hasPrefix("-ONEVOICE_") {
            let key = String(arguments[index].dropFirst())
            let valueIndex = arguments.index(after: index)
            guard arguments.indices.contains(valueIndex) else { continue }
            values[key] = arguments[valueIndex]
        }

        return values
    }
}
#endif
