import AppKit
import SwiftUI

struct OneVoiceMenuView: View {
    let model: OneVoiceMacModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button {
            model.toggleDictation()
        } label: {
            Text(dictationButtonTitle)
        }
        .disabled(model.isFinishing)
            .keyboardShortcut("d", modifiers: [.command, .shift])

        HStack(spacing: 4) {
            Text("Hold")
            Text(model.pushToTalkKey.title)
            Text("·")
            Text("Tap")
            Text(model.toggleKey.title)
        }
            .foregroundStyle(.secondary)

        Divider()

        Button {
            (NSApplication.shared.delegate as? OneVoiceMacAppDelegate)?.showMainWindow()
        } label: {
            HStack(spacing: 3) {
                Text("Open")
                Text(OneVoiceMacIdentity.displayName)
            }
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

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            HStack(spacing: 3) {
                Text("Quit")
                Text(OneVoiceMacIdentity.displayName)
            }
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var dictationButtonTitle: LocalizedStringResource {
        if model.isStarting { return "Cancel Starting" }
        if model.isRecording { return "Finish Dictation" }
        if model.isFinishing { return "Finishing…" }
        return "Start Dictation"
    }
}
