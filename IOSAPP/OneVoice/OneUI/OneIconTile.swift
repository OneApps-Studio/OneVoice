import SwiftUI

struct OneIconTile: View {
    let icon: String
    var tint: Color?
    var size: CGFloat = OneStyle.rowIconSize
    var cornerRadius: CGFloat = 9
    var style: OneIconTileStyle = .soft

    @Environment(\.oneAppTheme) private var theme

    var body: some View {
        ZStack {
            if style != .plain {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderFill, lineWidth: borderWidth)
                    }
            }

            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(symbolFill)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var resolvedTint: Color {
        tint ?? theme.primaryAccent
    }

    private var backgroundFill: Color {
        style == .solid ? resolvedTint : resolvedTint.opacity(0.14)
    }

    private var borderFill: Color {
        style == .solid ? .clear : resolvedTint.opacity(0.16)
    }

    private var borderWidth: CGFloat {
        style == .solid ? 0 : 1
    }

    private var symbolFill: Color {
        style == .solid ? .white : resolvedTint
    }
}
