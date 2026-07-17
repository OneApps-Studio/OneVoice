import SwiftUI

struct SettingsSelectionRow: View {
    let systemImage: String
    let iconColor: Color?
    let title: LocalizedStringResource
    var subtitle: LocalizedStringResource?
    let isSelected: Bool
    let select: () -> Void

    @Environment(\.oneAppTheme) private var theme

    var body: some View {
        Button(action: select) {
            OneRow(
                systemImage: systemImage,
                iconColor: iconColor,
                title: title,
                subtitle: subtitle
            ) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.bold())
                    .foregroundStyle(isSelected ? theme.primaryAccent : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? Text("Selected") : Text("Not Selected"))
    }
}
