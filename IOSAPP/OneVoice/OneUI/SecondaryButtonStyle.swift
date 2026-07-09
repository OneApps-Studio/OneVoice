import SwiftUI

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.oneAppTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.buttonSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: OneStyle.controlRadius, style: .continuous)
                    .fill(theme.buttonSecondaryFill.opacity(configuration.isPressed ? 0.72 : 1))
            )
            .overlay {
                RoundedRectangle(cornerRadius: OneStyle.controlRadius, style: .continuous)
                    .stroke(theme.buttonSecondaryStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: OneStyle.controlRadius, style: .continuous))
    }
}
