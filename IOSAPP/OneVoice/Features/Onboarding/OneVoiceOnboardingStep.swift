import SwiftUI

enum OneVoiceOnboardingStep: Int, CaseIterable, Identifiable {
    case privateSpeech
    case accurate
    case ready

    var id: Self { self }

    var next: OneVoiceOnboardingStep? {
        let allSteps = Self.allCases
        guard let index = allSteps.firstIndex(of: self),
              index < allSteps.index(before: allSteps.endIndex) else {
            return nil
        }
        return allSteps[allSteps.index(after: index)]
    }

    var isLast: Bool { next == nil }
    var showsLogo: Bool { self == .privateSpeech }
    var showsStudioFooter: Bool { self == .ready }
    var showsSkip: Bool { !isLast }

    var title: LocalizedStringResource {
        switch self {
        case .privateSpeech: "Your Voice Stays Yours"
        case .accurate: "Fast Live, Accurate Final"
        case .ready: "Speak, Save, Share"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .privateSpeech:
            "Record in the foreground or background, then transcribe on device. OneVoice has no audio server."
        case .accurate:
            "Apple Speech gives you live text. Download Qwen3-ASR when you want a more accurate offline final pass."
        case .ready:
            "Keep searchable voice notes, teach OneVoice your vocabulary, and paste the result anywhere."
        }
    }
}
