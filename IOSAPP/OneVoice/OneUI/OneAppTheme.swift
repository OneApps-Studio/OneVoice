import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum OneAppTheme: String, CaseIterable, Identifiable {
    case cleanBlue
    case sage
    case sand
    case graphite

    static let defaultTheme: OneAppTheme = .sage

    var id: String { rawValue }

    static var current: OneAppTheme {
        let stored = UserDefaults.standard.string(forKey: AppStorageKeys.appTheme)
        return OneAppTheme(rawValue: stored ?? defaultTheme.rawValue) ?? defaultTheme
    }

    var title: LocalizedStringResource {
        switch self {
        case .cleanBlue:
            return "Clean Blue"
        case .sage:
            return "Fresh Sage"
        case .sand:
            return "Warm Sand"
        case .graphite:
            return "Graphite"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .cleanBlue:
            return "Crisp, bright, and utility-first."
        case .sage:
            return "Soft, calm, and close to the OneVoice icon."
        case .sand:
            return "Warmer and more editorial."
        case .graphite:
            return "Quiet, focused, and neutral."
        }
    }

    var icon: String {
        switch self {
        case .cleanBlue:
            return "drop.fill"
        case .sage:
            return "leaf.fill"
        case .sand:
            return "sun.max.fill"
        case .graphite:
            return "circle.lefthalf.filled"
        }
    }

    var backgroundTop: Color { palette.backgroundTop.color }
    var backgroundBottom: Color { palette.backgroundBottom.color }
    var surface: Color { palette.surface.color }
    var elevatedSurface: Color { palette.elevatedSurface.color }
    var cardStroke: Color { palette.cardStroke.color }
    var hairline: Color { palette.hairline.color }
    var floatingShadow: Color { palette.floatingShadow.color }

    var primaryAccent: Color { palette.primaryAccent.color }
    var primaryAccentPressed: Color { palette.primaryAccentPressed.color }
    var primaryAccentOnFill: Color { palette.primaryAccentOnFill.color }
    var secondaryAccent: Color { palette.secondaryAccent.color }
    var success: Color { palette.success.color }
    var warning: Color { palette.warning.color }
    var danger: Color { palette.danger.color }
    var favorite: Color { palette.favorite.color }

    var primaryAccentSoftFill: Color { primaryAccent.opacity(0.14) }
    var primaryAccentSoftStroke: Color { primaryAccent.opacity(0.22) }
    var secondaryAccentSoftFill: Color { secondaryAccent.opacity(0.14) }
    var successSoftFill: Color { success.opacity(0.14) }
    var warningSoftFill: Color { warning.opacity(0.14) }
    var dangerSoftFill: Color { danger.opacity(0.14) }
    var buttonPrimaryFill: Color { primaryAccent }
    var buttonPrimaryText: Color { primaryAccentOnFill }
    var buttonSecondaryFill: Color { surface }
    var buttonSecondaryText: Color { primaryAccent }
    var buttonSecondaryStroke: Color { primaryAccentSoftStroke }
    var tabSelected: Color { primaryAccent }
    var navigationTint: Color { primaryAccent }
    var iconTileFill: Color { primaryAccentSoftFill }
    var iconTileStroke: Color { primaryAccentSoftStroke }

    var swatches: [Color] {
        [primaryAccent, secondaryAccent, backgroundBottom]
    }

    #if canImport(UIKit)
    var uiBackground: UIColor { palette.backgroundBottom.uiColor }
    var uiSurface: UIColor { palette.surface.uiColor }
    var uiAccent: UIColor { palette.primaryAccent.uiColor }
    var uiSecondaryText: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.58)
                : UIColor.secondaryLabel
        }
    }
    #endif

    private var palette: OneThemePalette {
        switch self {
        case .cleanBlue: return Self.cleanBluePalette
        case .sage: return Self.sagePalette
        case .sand: return Self.sandPalette
        case .graphite: return Self.graphitePalette
        }
    }

    private static let cleanBluePalette = OneThemePalette(
        backgroundTop: .init(light: .init(0.965, 0.982, 0.996), dark: .init(0.046, 0.052, 0.066)),
        backgroundBottom: .init(light: .init(0.926, 0.948, 0.978), dark: .init(0.034, 0.037, 0.046)),
        surface: .init(light: .init(1, 1, 1, 0.86), dark: .init(1, 1, 1, 0.075)),
        elevatedSurface: .init(light: .init(1, 1, 1, 0.94), dark: .init(1, 1, 1, 0.11)),
        cardStroke: .init(light: .init(0.18, 0.33, 0.48, 0.10), dark: .init(1, 1, 1, 0.115)),
        hairline: .init(light: .init(0.18, 0.33, 0.48, 0.13), dark: .init(1, 1, 1, 0.115)),
        floatingShadow: .init(light: .init(0, 0, 0, 0.08), dark: .init(0, 0, 0, 0.24)),
        primaryAccent: .init(light: .init(0.02, 0.45, 0.82), dark: .init(0.64, 0.78, 1)),
        primaryAccentPressed: .init(light: .init(0.01, 0.36, 0.68), dark: .init(0.52, 0.68, 0.92)),
        primaryAccentOnFill: .init(light: .init(1, 1, 1), dark: .init(0.03, 0.04, 0.05)),
        secondaryAccent: .init(light: .init(0.16, 0.58, 0.68), dark: .init(0.58, 0.86, 0.94)),
        success: .init(light: .init(0.06, 0.50, 0.22), dark: .init(0.50, 0.90, 0.64)),
        warning: .init(light: .init(0.78, 0.45, 0.02), dark: .init(1.00, 0.79, 0.47)),
        danger: .init(light: .init(0.86, 0.13, 0.12), dark: .init(1.00, 0.38, 0.34)),
        favorite: .init(light: .init(0.82, 0.16, 0.38), dark: .init(1.00, 0.62, 0.72))
    )

    private static let sagePalette = OneThemePalette(
        backgroundTop: .init(light: .init(0.982, 0.980, 0.944), dark: .init(0.044, 0.052, 0.047)),
        backgroundBottom: .init(light: .init(0.900, 0.928, 0.886), dark: .init(0.032, 0.038, 0.035)),
        surface: .init(light: .init(1, 1, 1, 0.82), dark: .init(1, 1, 1, 0.075)),
        elevatedSurface: .init(light: .init(1, 1, 1, 0.92), dark: .init(1, 1, 1, 0.11)),
        cardStroke: .init(light: .init(0.22, 0.42, 0.34, 0.11), dark: .init(1, 1, 1, 0.115)),
        hairline: .init(light: .init(0.22, 0.42, 0.34, 0.14), dark: .init(1, 1, 1, 0.115)),
        floatingShadow: .init(light: .init(0, 0, 0, 0.07), dark: .init(0, 0, 0, 0.24)),
        primaryAccent: .init(light: .init(0.18, 0.39, 0.31), dark: .init(0.62, 0.84, 0.72)),
        primaryAccentPressed: .init(light: .init(0.12, 0.30, 0.23), dark: .init(0.50, 0.72, 0.60)),
        primaryAccentOnFill: .init(light: .init(1, 1, 1), dark: .init(0.03, 0.04, 0.035)),
        secondaryAccent: .init(light: .init(0.62, 0.52, 0.30), dark: .init(0.86, 0.78, 0.52)),
        success: .init(light: .init(0.13, 0.46, 0.26), dark: .init(0.58, 0.88, 0.66)),
        warning: .init(light: .init(0.70, 0.48, 0.12), dark: .init(0.95, 0.78, 0.43)),
        danger: .init(light: .init(0.78, 0.16, 0.13), dark: .init(1.00, 0.44, 0.40)),
        favorite: .init(light: .init(0.76, 0.22, 0.42), dark: .init(1.00, 0.62, 0.74))
    )

    private static let sandPalette = OneThemePalette(
        backgroundTop: .init(light: .init(0.994, 0.968, 0.930), dark: .init(0.056, 0.046, 0.039)),
        backgroundBottom: .init(light: .init(0.956, 0.900, 0.820), dark: .init(0.040, 0.034, 0.030)),
        surface: .init(light: .init(1, 1, 1, 0.82), dark: .init(1, 1, 1, 0.075)),
        elevatedSurface: .init(light: .init(1, 1, 1, 0.92), dark: .init(1, 1, 1, 0.11)),
        cardStroke: .init(light: .init(0.56, 0.38, 0.18, 0.11), dark: .init(1, 1, 1, 0.115)),
        hairline: .init(light: .init(0.56, 0.38, 0.18, 0.14), dark: .init(1, 1, 1, 0.115)),
        floatingShadow: .init(light: .init(0.22, 0.12, 0.03, 0.09), dark: .init(0, 0, 0, 0.26)),
        primaryAccent: .init(light: .init(0.56, 0.38, 0.20), dark: .init(0.90, 0.72, 0.46)),
        primaryAccentPressed: .init(light: .init(0.45, 0.29, 0.13), dark: .init(0.78, 0.60, 0.36)),
        primaryAccentOnFill: .init(light: .init(1, 1, 1), dark: .init(0.04, 0.035, 0.03)),
        secondaryAccent: .init(light: .init(0.78, 0.45, 0.16), dark: .init(1.00, 0.78, 0.48)),
        success: .init(light: .init(0.34, 0.46, 0.20), dark: .init(0.72, 0.86, 0.52)),
        warning: .init(light: .init(0.80, 0.45, 0.08), dark: .init(1.00, 0.78, 0.45)),
        danger: .init(light: .init(0.78, 0.18, 0.12), dark: .init(1.00, 0.46, 0.38)),
        favorite: .init(light: .init(0.72, 0.25, 0.36), dark: .init(1.00, 0.64, 0.72))
    )

    private static let graphitePalette = OneThemePalette(
        backgroundTop: .init(light: .init(0.960, 0.966, 0.976), dark: .init(0.038, 0.041, 0.047)),
        backgroundBottom: .init(light: .init(0.895, 0.904, 0.922), dark: .init(0.030, 0.032, 0.038)),
        surface: .init(light: .init(1, 1, 1, 0.84), dark: .init(1, 1, 1, 0.075)),
        elevatedSurface: .init(light: .init(1, 1, 1, 0.94), dark: .init(1, 1, 1, 0.11)),
        cardStroke: .init(light: .init(0.18, 0.22, 0.28, 0.11), dark: .init(1, 1, 1, 0.115)),
        hairline: .init(light: .init(0.18, 0.22, 0.28, 0.14), dark: .init(1, 1, 1, 0.115)),
        floatingShadow: .init(light: .init(0, 0, 0, 0.08), dark: .init(0, 0, 0, 0.25)),
        primaryAccent: .init(light: .init(0.25, 0.34, 0.46), dark: .init(0.72, 0.80, 0.90)),
        primaryAccentPressed: .init(light: .init(0.17, 0.25, 0.36), dark: .init(0.60, 0.69, 0.80)),
        primaryAccentOnFill: .init(light: .init(1, 1, 1), dark: .init(0.03, 0.035, 0.04)),
        secondaryAccent: .init(light: .init(0.43, 0.48, 0.55), dark: .init(0.78, 0.82, 0.88)),
        success: .init(light: .init(0.18, 0.44, 0.28), dark: .init(0.60, 0.86, 0.68)),
        warning: .init(light: .init(0.68, 0.48, 0.16), dark: .init(0.94, 0.76, 0.44)),
        danger: .init(light: .init(0.78, 0.16, 0.14), dark: .init(1.00, 0.44, 0.40)),
        favorite: .init(light: .init(0.68, 0.24, 0.42), dark: .init(0.95, 0.62, 0.76))
    )
}
