import SwiftUI

struct ContentView: View {
    let model: OneVoiceMobileModel
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView(model: model)
            } else {
                OnboardingView {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
        .task { await model.launch() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            Task { await model.prepareForBackground() }
        }
    }
}

#Preview {
    ContentView(model: .shared)
}
