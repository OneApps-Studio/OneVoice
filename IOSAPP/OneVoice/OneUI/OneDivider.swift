import SwiftUI

struct OneDivider: View {
    @Environment(\.oneAppTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(height: 1)
            .padding(.leading, 60)
    }
}
