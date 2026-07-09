import AppKit
import ApplicationServices
import OneVoiceCore

@MainActor
final class MacTextInsertion: TextInsertion {
    private struct CapturedTarget {
        let application: NSRunningApplication
        let element: AXUIElement
    }

    private var targets: [UUID: CapturedTarget] = [:]

    func captureTarget() -> TextInsertionTarget? {
        guard AXIsProcessTrusted(),
              let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier != Bundle.main.bundleIdentifier,
              let element = focusedElement() else {
            return nil
        }
        let target = TextInsertionTarget()
        targets[target.id] = CapturedTarget(application: application, element: element)
        return target
    }

    func insert(_ text: String, into target: TextInsertionTarget?) async -> TextInsertionOutcome {
        guard !text.isEmpty else { return .failed("The transcript is empty.") }
        guard let target, let captured = targets.removeValue(forKey: target.id) else {
            copyToClipboard(text)
            return .copiedToClipboard
        }
        guard !isSecure(captured.element) else {
            copyToClipboard(text)
            return .blockedSecureField
        }

        _ = captured.application.activate(options: [])
        AXUIElementSetAttributeValue(
            captured.element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )

        var isSettable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(
            captured.element,
            kAXSelectedTextAttribute as CFString,
            &isSettable
        ) == .success, isSettable.boolValue,
           AXUIElementSetAttributeValue(
               captured.element,
               kAXSelectedTextAttribute as CFString,
               text as CFString
           ) == .success {
            return .insertedDirectly
        }

        return await paste(text, into: captured.application)
    }

    private func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success, let value else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func isSecure(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &value
        ) == .success, let subrole = value as? String else {
            return false
        }
        return subrole == "AXSecureTextField"
    }

    private func paste(_ text: String, into application: NSRunningApplication) async -> TextInsertionOutcome {
        let pasteboard = NSPasteboard.general
        let snapshot = pasteboard.pasteboardItems?.compactMap(copyPasteboardItem) ?? []
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            return .failed("The clipboard could not be updated.")
        }
        let temporaryChangeCount = pasteboard.changeCount

        try? await Task.sleep(for: .milliseconds(80))
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return .copiedToClipboard
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(application.processIdentifier)
        keyUp.postToPid(application.processIdentifier)

        try? await Task.sleep(for: .milliseconds(350))
        if pasteboard.changeCount == temporaryChangeCount {
            pasteboard.clearContents()
            if !snapshot.isEmpty {
                pasteboard.writeObjects(snapshot)
            }
        }
        return .pastedFromClipboard
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyPasteboardItem(_ item: NSPasteboardItem) -> NSPasteboardItem? {
        let copy = NSPasteboardItem()
        var copied = false
        for type in item.types {
            if let data = item.data(forType: type) {
                copy.setData(data, forType: type)
                copied = true
            }
        }
        return copied ? copy : nil
    }
}
