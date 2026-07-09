import SwiftUI

struct OnboardingFooter: View {
    let selectedStep: OneVoiceOnboardingStep
    let nextAction: () -> Void
    let completeAction: () -> Void

    var body: some View {
        OneSectionStack(spacing: 16) {
            VStack(spacing: 16) {
                OnboardingPageDots(selectedStep: selectedStep)

                Button(action: selectedStep.isLast ? completeAction : nextAction) {
                    if selectedStep.isLast {
                        Text("Start")
                    } else {
                        Text("Next")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier(selectedStep.isLast ? "onboarding-start-button" : "onboarding-next-button")
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}
