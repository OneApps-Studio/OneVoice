import SwiftUI

struct QwenModelSettingsSection: View {
    let model: OneVoiceMobileModel

    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Qwen3-ASR 0.6B").font(.headline)
                    Text("High-accuracy offline final pass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Group {
                    if model.qwenInstalled {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                    } else {
                        Label("Optional", systemImage: "arrow.down.circle")
                    }
                }
                .font(.caption)
                .foregroundStyle(model.qwenInstalled ? .green : .secondary)
            }

            if model.qwenIsDownloading {
                ProgressView(value: model.qwenDownloadProgress) {
                    Text("Downloading Qwen3-ASR… \(Int(model.qwenDownloadProgress * 100))%")
                }
            } else if model.qwenInstalled {
                Toggle("Use for final transcript", isOn: Bindable(model).useQwenFinalPass)
                Button("Remove Download", role: .destructive) {
                    Task { await model.removeQwenModel() }
                }
            } else {
                Button("Download Model") {
                    Task { await model.downloadQwenModel() }
                }
                Text("About 0.7–1 GB. Wi-Fi recommended. After download it runs entirely offline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Accurate model")
        }
    }
}
