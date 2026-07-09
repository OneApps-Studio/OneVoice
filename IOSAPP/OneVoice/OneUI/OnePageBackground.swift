import SwiftUI

struct OnePageBackground: View {
    @Environment(\.oneAppTheme) private var theme

    var body: some View {
        LinearGradient(
            colors: [
                theme.backgroundTop,
                theme.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
