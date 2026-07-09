import AppKit
import SwiftUI

@main
struct OneVoiceMacApp: App {
    @NSApplicationDelegateAdaptor(OneVoiceMacAppDelegate.self) private var appDelegate
    private let model = OneVoiceMacModel.shared

    var body: some Scene {
        MenuBarExtra("OneVoice", systemImage: "waveform") {
            OneVoiceMenuView(model: model)
                .task { await model.launch() }
        }

        Settings {
            OneVoiceMacSettingsView(model: model)
                .frame(width: 560, height: 440)
        }
    }
}

@MainActor
final class OneVoiceMacAppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            let model = OneVoiceMacModel.shared
            await model.launch()
            let defaults = UserDefaults.standard
            if !defaults.bool(forKey: "didShowInitialWindow") || !model.missingPermissions.isEmpty {
                showMainWindow()
                defaults.set(true, forKey: "didShowInitialWindow")
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        OneVoiceMacModel.shared.refreshPermissionStatus()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showMainWindow() {
        if let window = mainWindowController?.window {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = OneVoiceMacHomeView(model: .shared)
            .frame(minWidth: 720, minHeight: 520)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "OneVoice"
        window.identifier = NSUserInterfaceItemIdentifier("OneVoiceMainWindow")
        window.minSize = NSSize(width: 720, height: 520)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        if let visibleFrame = NSScreen.screens.first?.visibleFrame {
            window.setFrameOrigin(NSPoint(
                x: visibleFrame.midX - window.frame.width / 2,
                y: visibleFrame.midY - window.frame.height / 2
            ))
        }
        window.contentViewController = NSHostingController(rootView: rootView)

        let controller = NSWindowController(window: window)
        mainWindowController = controller
        NSApplication.shared.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
    }
}
