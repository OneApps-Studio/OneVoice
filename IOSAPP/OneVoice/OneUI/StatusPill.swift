import SwiftUI

struct StatusPill: View {
    var titleText: Text
    var tone: StatusPillTone

    @Environment(\.oneAppTheme) private var theme

    init(title: LocalizedStringResource, tone: StatusPillTone) {
        self.titleText = Text(title)
        self.tone = tone
    }

    init(verbatim title: String, tone: StatusPillTone) {
        self.titleText = Text(verbatim: title)
        self.tone = tone
    }

    init(titleText: Text, tone: StatusPillTone) {
        self.titleText = titleText
        self.tone = tone
    }

    var body: some View {
        let tint = tone.color(in: theme)

        titleText
            .font(.footnote.bold())
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(tint.opacity(0.13), in: Capsule())
    }
}
