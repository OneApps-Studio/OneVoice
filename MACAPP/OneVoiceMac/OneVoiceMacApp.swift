import AppKit
import SwiftUI

@main
struct OneVoiceMacApp: App {
    @NSApplicationDelegateAdaptor(OneVoiceMacAppDelegate.self) private var appDelegate
    private let model = OneVoiceMacModel.shared

    var body: some Scene {
        MenuBarExtra(OneVoiceMacIdentity.displayName, systemImage: "waveform") {
            OneVoiceMenuView(model: model)
                .environment(\.locale, model.appLanguage.locale)
                .task { await model.launch() }
        }

        Settings {
            OneVoiceMacSettingsView(model: model)
                .environment(\.locale, model.appLanguage.locale)
                .frame(width: 620, height: 520)
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
            #if DEBUG
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--onevoice-ui-testing")
            #else
            let isUITesting = false
            #endif
            if isUITesting || !defaults.bool(forKey: "didShowInitialWindow") || !model.missingPermissions.isEmpty {
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

        let rootView = OneVoiceMacLocalizedHomeView(model: .shared)
            .frame(minWidth: 720, minHeight: 520)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = OneVoiceMacIdentity.displayName
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

private struct OneVoiceMacLocalizedHomeView: View {
    let model: OneVoiceMacModel

    var body: some View {
        OneVoiceMacHomeView(model: model)
            .environment(\.locale, model.appLanguage.locale)
    }
}
