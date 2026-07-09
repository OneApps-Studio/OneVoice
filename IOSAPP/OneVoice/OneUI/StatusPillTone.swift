import SwiftUI

enum StatusPillTone {
    case success
    case warning
    case neutral

    func color(in theme: OneAppTheme) -> Color {
        switch self {
        case .success:
            theme.success
        case .warning:
            theme.warning
        case .neutral:
            theme.secondaryAccent
        }
    }
}
