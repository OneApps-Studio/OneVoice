import SwiftUI

struct OnboardingPageDots: View {
    let selectedStep: OneVoiceOnboardingStep

    @Environment(\.oneAppTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OneVoiceOnboardingStep.allCases) { step in
                Capsule()
                    .fill(step == selectedStep ? theme.primaryAccent : theme.hairline)
                    .frame(width: step == selectedStep ? 22 : 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}
