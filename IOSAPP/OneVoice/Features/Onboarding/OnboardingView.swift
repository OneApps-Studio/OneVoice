import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var selectedStep = OneVoiceOnboardingStep.privateSpeech

    var body: some View {
        ZStack {
            OnePageBackground()

            VStack(spacing: 0) {
                TabView(selection: $selectedStep) {
                    ForEach(OneVoiceOnboardingStep.allCases) { step in
                        OneVoiceOnboardingPage(step: step)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                OnboardingFooter(
                    selectedStep: selectedStep,
                    nextAction: advance,
                    completeAction: complete
                )
                .padding(.horizontal, OneStyle.screenHorizontalPadding)
                .padding(.bottom, 28)
            }

            // Skip — top-right, hidden on last page
            if selectedStep.showsSkip {
                VStack {
                    HStack {
                        Spacer()
                        Button("Skip") { complete() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }
                    Spacer()
                }
            }
        }
    }

    private func advance() {
        guard let nextStep = selectedStep.next else {
            complete()
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            selectedStep = nextStep
        }
    }

    private func complete() {
        onComplete()
    }
}

#Preview {
    OnboardingView {}
        .environment(\.oneAppTheme, .sage)
}
