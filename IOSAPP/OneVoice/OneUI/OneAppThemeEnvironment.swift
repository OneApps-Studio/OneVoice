import SwiftUI

private struct OneAppThemeKey: EnvironmentKey {
    static let defaultValue = OneAppTheme.defaultTheme
}

extension EnvironmentValues {
    var oneAppTheme: OneAppTheme {
        get { self[OneAppThemeKey.self] }
        set { self[OneAppThemeKey.self] = newValue }
    }
}
