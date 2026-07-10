import Testing
import OneVoiceCore
import UIKit
@testable import OneVoice

@MainActor
@Test("Completed mobile transcripts are copied to the system pasteboard")
func copiesCompletedTranscript() async {
    let insertion = MobileClipboardInsertion()
    let outcome = await insertion.insert("OneVoice offline test", into: TextInsertionTarget())

    #expect(outcome == .copiedToClipboard)
    #expect(UIPasteboard.general.string == "OneVoice offline test")
}
