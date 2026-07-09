import SwiftUI

struct OneRow<Accessory: View>: View {
    var systemImage: String
    var iconColor: Color?
    var titleText: Text
    var subtitleText: Text?
    @ViewBuilder var accessory: Accessory

    @Environment(\.oneAppTheme) private var theme

    init(
        systemImage: String,
        iconColor: Color? = nil,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.titleText = Text(title)
        self.subtitleText = subtitle.map { Text($0) }
        self.accessory = accessory()
    }

    init(
        systemImage: String,
        iconColor: Color? = nil,
        verbatim title: String,
        verbatimSubtitle subtitle: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.titleText = Text(verbatim: title)
        self.subtitleText = subtitle.map { Text(verbatim: $0) }
        self.accessory = accessory()
    }

    init(
        systemImage: String,
        iconColor: Color? = nil,
        titleText: Text,
        subtitleText: Text? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.titleText = titleText
        self.subtitleText = subtitleText
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            OneIconTile(icon: systemImage, tint: iconColor ?? theme.primaryAccent)

            VStack(alignment: .leading, spacing: 4) {
                titleText
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                if let subtitleText {
                    subtitleText
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: OneStyle.rowMinHeight)
        .contentShape(Rectangle())
    }
}
