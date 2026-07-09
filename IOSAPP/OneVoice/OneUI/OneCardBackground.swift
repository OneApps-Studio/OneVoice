import SwiftUI

struct OneCardBackground: ViewModifier {
    var radius: CGFloat = OneStyle.cardRadius
    var isInteractive = false

    @Environment(\.oneAppTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(isInteractive ? theme.primaryAccentSoftStroke : theme.cardStroke, lineWidth: 1)
                    }
            )
    }
}

extension View {
    func oneCard(radius: CGFloat = OneStyle.cardRadius, isInteractive: Bool = false) -> some View {
        modifier(OneCardBackground(radius: radius, isInteractive: isInteractive))
    }
}
