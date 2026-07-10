import AppKit
import SwiftUI

struct OneVoiceMenuView: View {
    let model: OneVoiceMacModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(dictationButtonTitle) {
            model.toggleDictation()
        }
        .disabled(model.isFinishing)
            .keyboardShortcut("d", modifiers: [.command, .shift])

        Text("Hold Fn · Tap Right Command")
            .foregroundStyle(.secondary)

        Divider()

        Button("Open \(OneVoiceMacIdentity.displayName)") {
            (NSApplication.shared.delegate as? OneVoiceMacAppDelegate)?.showMainWindow()
        }

        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        if let error = model.lastError {
            Divider()
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }

        if let message = model.lastDeliveryMessage {
            Divider()
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Divider()

        Button("Quit \(OneVoiceMacIdentity.displayName)") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var dictationButtonTitle: String {
        if model.isStarting { return "Cancel Starting" }
        if model.isRecording { return "Finish Dictation" }
        if model.isFinishing { return "Finishing…" }
        return "Start Dictation"
    }
}
