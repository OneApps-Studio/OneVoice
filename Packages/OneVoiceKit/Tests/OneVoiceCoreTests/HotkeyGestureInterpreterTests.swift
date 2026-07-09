import OneVoiceCore
import Testing

@Suite("Hotkey gesture interpreter")
struct HotkeyGestureInterpreterTests {
    @Test("Fn hold arms capture, starts after the threshold, and finishes on release")
    func functionHoldToTalk() {
        var interpreter = HotkeyGestureInterpreter()

        #expect(interpreter.handle(.modifierDown(.function, at: 1.0)) == [.armCapture])
        #expect(interpreter.handle(.holdThresholdElapsed(.function, at: 1.2)) == [.beginPushToTalk])
        #expect(interpreter.handle(.modifierUp(.function, at: 2.0)) == [.finishRecording])
    }

    @Test("A long right Command press is not treated as a toggle gesture")
    func longRightCommandDoesNotToggle() {
        var interpreter = HotkeyGestureInterpreter(maximumTapDuration: 0.3)

        #expect(interpreter.handle(.modifierDown(.rightCommand, at: 1.0)).isEmpty)
        #expect(interpreter.handle(.modifierUp(.rightCommand, at: 1.5)).isEmpty)
    }

    @Test("A short Fn press is cancelled without starting a recording")
    func shortFunctionPressCancels() {
        var interpreter = HotkeyGestureInterpreter()

        #expect(interpreter.handle(.modifierDown(.function, at: 1.0)) == [.armCapture])
        #expect(interpreter.handle(.modifierUp(.function, at: 1.1)) == [.cancelCapture])
    }

    @Test("A short right Command press toggles recording")
    func shortRightCommandToggles() {
        var interpreter = HotkeyGestureInterpreter(maximumTapDuration: 0.3)

        #expect(interpreter.handle(.modifierDown(.rightCommand, at: 1.0)).isEmpty)
        #expect(interpreter.handle(.modifierUp(.rightCommand, at: 1.2)) == [.toggleRecording])
    }

    @Test("Using right Command as a chord never toggles recording")
    func rightCommandChordDoesNotToggle() {
        var interpreter = HotkeyGestureInterpreter()

        #expect(interpreter.handle(.modifierDown(.rightCommand, at: 1.0)).isEmpty)
        #expect(interpreter.handle(.otherKeyDown(at: 1.05)).isEmpty)
        #expect(interpreter.handle(.modifierUp(.rightCommand, at: 1.1)).isEmpty)
    }

    @Test("Typing another key while Fn push-to-talk is active always finishes recording")
    func functionChordFinishesActiveRecording() {
        var interpreter = HotkeyGestureInterpreter()

        #expect(interpreter.handle(.modifierDown(.function, at: 1.0)) == [.armCapture])
        #expect(interpreter.handle(.holdThresholdElapsed(.function, at: 1.2)) == [.beginPushToTalk])
        #expect(interpreter.handle(.otherKeyDown(at: 1.4)) == [.finishRecording])
        #expect(interpreter.handle(.modifierUp(.function, at: 1.5)).isEmpty)
    }
}
