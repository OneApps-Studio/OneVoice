import SwiftUI

struct OneSection<Content: View>: View {
    let titleText: Text
    @ViewBuilder let content: Content

    init(title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
        self.titleText = Text(title)
        self.content = content()
    }

    init(verbatim title: String, @ViewBuilder content: () -> Content) {
        self.titleText = Text(verbatim: title)
        self.content = content()
    }

    init(titleText: Text, @ViewBuilder content: () -> Content) {
        self.titleText = titleText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                titleText
                    .oneSectionHeading()
                Spacer()
            }

            VStack(spacing: 0) {
                content
            }
            .oneCard()
        }
    }
}
