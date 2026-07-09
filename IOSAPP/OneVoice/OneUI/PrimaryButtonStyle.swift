import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.oneAppTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.buttonPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: OneStyle.controlRadius, style: .continuous)
                    .fill(configuration.isPressed ? theme.primaryAccentPressed : theme.buttonPrimaryFill)
            )
            .clipShape(RoundedRectangle(cornerRadius: OneStyle.controlRadius, style: .continuous))
    }
}
