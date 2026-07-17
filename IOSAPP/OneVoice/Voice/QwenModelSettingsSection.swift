import SwiftUI

struct QwenModelSettingsSection: View {
    let model: OneVoiceMobileModel

    @Environment(\.oneAppTheme) private var theme

    var body: some View {
        OneSection(title: "Accurate Model") {
            OneRow(
                systemImage: "brain.head.profile",
                title: "Qwen3-ASR 0.6B",
                subtitle: "Optional high-accuracy offline final transcript"
            ) {
                Label(
                    model.qwenInstalled ? "Installed" : "Optional",
                    systemImage: model.qwenInstalled ? "checkmark.circle.fill" : "arrow.down.circle"
                )
                .font(.caption)
                .foregroundStyle(model.qwenInstalled ? theme.success : .secondary)
            }

            OneDivider()

            if model.qwenIsDownloading {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: model.qwenDownloadProgress)
                    Text("Downloading Qwen3-ASR… \(Int(model.qwenDownloadProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            } else if model.qwenInstalled {
                Toggle(isOn: Bindable(model).useQwenFinalPass) {
                    OneRow(
                        systemImage: "checkmark.message",
                        title: "Use for Final Transcript"
                    )
                }
                .toggleStyle(.switch)
                .padding(.trailing, 16)

                OneDivider()

                Button(role: .destructive) {
                    Task { await model.removeQwenModel() }
                } label: {
                    OneRow(
                        systemImage: "trash",
                        iconColor: theme.danger,
                        title: "Remove Download"
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await model.downloadQwenModel() }
                } label: {
                    OneRow(
                        systemImage: "arrow.down.circle",
                        title: "Download Model",
                        subtitle: "About 0.7–1 GB · Wi-Fi recommended"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.footnote.bold())
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
