import AppKit
import SwiftUI

@MainActor
final class DictationOverlayController {
    private var panel: NSPanel?

    func show(model: OneVoiceMacModel) {
        let panel = panel ?? makePanel(model: model)
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel(model: OneVoiceMacModel) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 92),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: DictationOverlayView(model: model))
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.minY + 72
        ))
    }
}

private struct DictationOverlayView: View {
    let model: OneVoiceMacModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white, .red)
                .symbolEffect(.pulse, options: .repeating)

            VStack(alignment: .leading, spacing: 5) {
                if model.isRecording {
                    Text("Listening…")
                        .font(.headline)
                } else {
                    Text("Finishing…")
                        .font(.headline)
                }
                if model.liveTranscript.isEmpty {
                    Text("Speak naturally")
                        .font(.callout)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.liveTranscript)
                        .font(.callout)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(width: 430, height: 92)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.18))
        }
    }
}
