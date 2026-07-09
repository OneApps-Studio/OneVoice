import SwiftUI

enum OneStyle {
    static let screenHorizontalPadding: CGFloat = 20
    static let cardRadius: CGFloat = 22
    static let controlRadius: CGFloat = 14
    static let sectionSpacing: CGFloat = 24
    static let rootContentTopSpacing: CGFloat = 8
    static let rowIconSize: CGFloat = 32
    static let rowMinHeight: CGFloat = 58
    static let compactRowMinHeight: CGFloat = 46

    static var primaryText: Color { .primary }
    static var secondaryText: Color { .secondary }
    static var tertiaryText: Color { .secondary }

    static func readableContentMaxWidth(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat? {
        horizontalSizeClass == .regular ? 760 : nil
    }

    static func homeContentMaxWidth(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        prefersExpandedContent(in: size, horizontalSizeClass: horizontalSizeClass) ? min(size.width - 48, 1040) : 560
    }

    static func homeHorizontalPadding(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        prefersExpandedContent(in: size, horizontalSizeClass: horizontalSizeClass) ? 32 : screenHorizontalPadding
    }

    static func prefersExpandedContent(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        horizontalSizeClass == .regular && size.width >= 760 && size.height >= 560
    }
}
