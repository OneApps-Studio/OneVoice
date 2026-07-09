import CoreGraphics
import Foundation
import OneVoiceCore

@MainActor
final class GlobalHotkeyMonitor {
    typealias ActionHandler = @MainActor (HotkeyGestureInterpreter.Action) -> Void

    private let actionHandler: ActionHandler
    private var interpreter = HotkeyGestureInterpreter()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var functionIsDown = false
    private var rightCommandIsDown = false
    private var functionHoldTask: Task<Void, Never>?

    init(actionHandler: @escaping ActionHandler) {
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
        functionHoldTask?.cancel()
        functionHoldTask = nil
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
            functionHoldTask?.cancel()
            return
        }

        guard type == .flagsChanged else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch keyCode {
        case 63:
            let isDown = event.flags.contains(.maskSecondaryFn)
            guard isDown != functionIsDown else { return }
            functionIsDown = isDown
            if isDown {
                dispatch(interpreter.handle(.modifierDown(.function, at: timestamp)))
                functionHoldTask?.cancel()
                functionHoldTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(180))
                    guard !Task.isCancelled, let self, self.functionIsDown else { return }
                    self.dispatch(self.interpreter.handle(
                        .holdThresholdElapsed(.function, at: ProcessInfo.processInfo.systemUptime)
                    ))
                }
            } else {
                functionHoldTask?.cancel()
                functionHoldTask = nil
                dispatch(interpreter.handle(.modifierUp(.function, at: timestamp)))
            }
        case 54:
            let isDown = event.flags.contains(.maskCommand)
            guard isDown != rightCommandIsDown else { return }
            rightCommandIsDown = isDown
            let event: HotkeyGestureInterpreter.Event = isDown
                ? .modifierDown(.rightCommand, at: timestamp)
                : .modifierUp(.rightCommand, at: timestamp)
            dispatch(interpreter.handle(event))
        default:
            break
        }
    }

    private func dispatch(_ actions: [HotkeyGestureInterpreter.Action]) {
        for action in actions {
            actionHandler(action)
        }
    }
}
