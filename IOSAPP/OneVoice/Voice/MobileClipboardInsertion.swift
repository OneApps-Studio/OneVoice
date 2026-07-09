import OneVoiceCore
import UIKit

@MainActor
final class MobileClipboardInsertion: TextInsertion {
    func captureTarget() -> TextInsertionTarget? {
        TextInsertionTarget()
    }

    func insert(_ text: String, into target: TextInsertionTarget?) async -> TextInsertionOutcome {
        UIPasteboard.general.string = text
        return .copiedToClipboard
    }
}
