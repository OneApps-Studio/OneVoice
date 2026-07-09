import SwiftUI

struct OneSectionHeading: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

extension View {
    func oneSectionHeading() -> some View {
        modifier(OneSectionHeading())
    }
}
