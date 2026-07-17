import SwiftUI

struct SettingsThemeOptionRow: View {
    let appTheme: OneAppTheme
    let isSelected: Bool
    let select: () -> Void

    @Environment(\.oneAppTheme) private var currentTheme

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: -4) {
                    ForEach(appTheme.swatches.indices, id: \.self) { index in
                        Circle()
                            .fill(appTheme.swatches[index])
                            .frame(width: 22, height: 22)
                            .overlay { Circle().stroke(.white.opacity(0.82), lineWidth: 1) }
                    }
                }
                .frame(width: 54, alignment: .leading)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appTheme.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(appTheme.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? currentTheme.primaryAccent : Color.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? currentTheme.primaryAccentSoftFill : currentTheme.elevatedSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? currentTheme.primaryAccentSoftStroke : currentTheme.hairline, lineWidth: 1)
                    }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appTheme.title)
    }
}
