import CoreGraphics
import Foundation
import OneVoiceCore

enum GlobalHotkeyKey: String, CaseIterable, Identifiable, Sendable {
    case function
    case rightCommand
    case leftCommand
    case rightOption
    case leftOption
    case rightControl
    case leftControl

    static let defaultPushToTalk: Self = .function
    static let defaultToggle: Self = .rightCommand

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .function: "Fn"
        case .rightCommand: "Right Command"
        case .leftCommand: "Left Command"
        case .rightOption: "Right Option"
        case .leftOption: "Left Option"
        case .rightControl: "Right Control"
        case .leftControl: "Left Control"
        }
    }

    var keyCode: Int64 {
        switch self {
        case .function: 63
        case .rightCommand: 54
        case .leftCommand: 55
        case .rightOption: 61
        case .leftOption: 58
        case .rightControl: 62
        case .leftControl: 59
        }
    }

    var eventFlag: CGEventFlags {
        switch self {
        case .function: .maskSecondaryFn
        case .rightCommand, .leftCommand: .maskCommand
        case .rightOption, .leftOption: .maskAlternate
        case .rightControl, .leftControl: .maskControl
        }
    }

    static func fallback(excluding key: Self, preferred: Self) -> Self {
        if preferred != key { return preferred }
        return allCases.first { $0 != key } ?? .function
    }
}

@MainActor
final class GlobalHotkeyMonitor {
    typealias ActionHandler = @MainActor (HotkeyGestureInterpreter.Action) -> Void

    private let actionHandler: ActionHandler
    private let pushToTalkKey: GlobalHotkeyKey
    private let toggleKey: GlobalHotkeyKey
    private var interpreter = HotkeyGestureInterpreter()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pushToTalkIsDown = false
    private var toggleIsDown = false
    private var pushToTalkHoldTask: Task<Void, Never>?

    init(
        pushToTalkKey: GlobalHotkeyKey,
        toggleKey: GlobalHotkeyKey,
        actionHandler: @escaping ActionHandler
    ) {
        precondition(pushToTalkKey != toggleKey, "Global shortcut keys must be different")
        self.pushToTalkKey = pushToTalkKey
        self.toggleKey = toggleKey
        self.actionHandler = actionHandler
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                monitor.receive(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        pushToTalkHoldTask?.cancel()
        pushToTalkHoldTask = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        let timestamp = ProcessInfo.processInfo.systemUptime
        if type == .keyDown {
            dispatch(interpreter.handle(.otherKeyDown(at: timestamp)))
            pushToTalkHoldTask?.cancel()
            return
        }

        guard type == .flagsChanged else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == pushToTalkKey.keyCode {
            let isDown = isKeyDown(
                pushToTalkKey,
                currentState: pushToTalkIsDown,
                event: event
            )
            guard isDown != pushToTalkIsDown else { return }
            pushToTalkIsDown = isDown
            if isDown {
                dispatch(interpreter.handle(.modifierDown(.function, at: timestamp)))
                pushToTalkHoldTask?.cancel()
                pushToTalkHoldTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(180))
                    guard !Task.isCancelled, let self, self.pushToTalkIsDown else { return }
                    self.dispatch(self.interpreter.handle(
                        .holdThresholdElapsed(.function, at: ProcessInfo.processInfo.systemUptime)
                    ))
                }
            } else {
                pushToTalkHoldTask?.cancel()
                pushToTalkHoldTask = nil
                dispatch(interpreter.handle(.modifierUp(.function, at: timestamp)))
            }
            return
        }

        if keyCode == toggleKey.keyCode {
            let isDown = isKeyDown(
                toggleKey,
                currentState: toggleIsDown,
                event: event
            )
            guard isDown != toggleIsDown else { return }
            toggleIsDown = isDown
            let shortcutEvent: HotkeyGestureInterpreter.Event = isDown
                ? .modifierDown(.rightCommand, at: timestamp)
                : .modifierUp(.rightCommand, at: timestamp)
            dispatch(interpreter.handle(shortcutEvent))
        }
    }

    private func isKeyDown(
        _ key: GlobalHotkeyKey,
        currentState: Bool,
        event: CGEvent
    ) -> Bool {
        if CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(key.keyCode)) {
            return true
        }
        if currentState {
            return false
        }
        return event.flags.contains(key.eventFlag)
    }

    private func dispatch(_ actions: [HotkeyGestureInterpreter.Action]) {
        for action in actions {
            actionHandler(action)
        }
    }
}
