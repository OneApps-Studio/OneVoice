import Foundation

public struct HotkeyGestureInterpreter: Sendable {
    public enum Modifier: Sendable, Equatable {
        case function
        case rightCommand
    }

    public enum Event: Sendable, Equatable {
        case modifierDown(Modifier, at: TimeInterval)
        case holdThresholdElapsed(Modifier, at: TimeInterval)
        case modifierUp(Modifier, at: TimeInterval)
        case otherKeyDown(at: TimeInterval)
    }

    public enum Action: Sendable, Equatable {
        case armCapture
        case beginPushToTalk
        case finishRecording
        case cancelCapture
        case toggleRecording
    }

    private var pressedModifier: Modifier?
    private var pressedAt: TimeInterval?
    private var pushToTalkIsActive = false
    private let maximumTapDuration: TimeInterval

    public init(maximumTapDuration: TimeInterval = 0.3) {
        self.maximumTapDuration = maximumTapDuration
    }

    public mutating func handle(_ event: Event) -> [Action] {
        switch event {
        case .modifierDown(let modifier, let timestamp):
            guard pressedModifier == nil else { return [] }
            pressedModifier = modifier
            pressedAt = timestamp
            pushToTalkIsActive = false
            return modifier == .function ? [.armCapture] : []

        case .holdThresholdElapsed(let modifier, _):
            guard pressedModifier == modifier,
                  modifier == .function,
                  !pushToTalkIsActive
            else {
                return []
            }
            pushToTalkIsActive = true
            return [.beginPushToTalk]

        case .modifierUp(let modifier, let timestamp):
            guard pressedModifier == modifier, let pressedAt else { return [] }
            pressedModifier = nil
            self.pressedAt = nil
            if modifier == .function {
                defer { pushToTalkIsActive = false }
                return pushToTalkIsActive ? [.finishRecording] : [.cancelCapture]
            }
            return timestamp - pressedAt <= maximumTapDuration ? [.toggleRecording] : []

        case .otherKeyDown:
            let shouldFinishRecording = pressedModifier == .function && pushToTalkIsActive
            pressedModifier = nil
            pressedAt = nil
            pushToTalkIsActive = false
            return shouldFinishRecording ? [.finishRecording] : []
        }
    }
}
