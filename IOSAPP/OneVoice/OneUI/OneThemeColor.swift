import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct OneThemeColor {
    let light: OneRGBA
    let dark: OneRGBA

    init(light: OneRGBA, dark: OneRGBA) {
        self.light = light
        self.dark = dark
    }

    var color: Color {
        #if canImport(UIKit)
        Color(uiColor: uiColor)
        #else
        Color(red: light.red, green: light.green, blue: light.blue).opacity(light.alpha)
        #endif
    }

    #if canImport(UIKit)
    var uiColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor
        }
    }
    #endif
}
