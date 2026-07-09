import SwiftUI

struct SettingsLanguageView: View {
    @Binding var appLanguageValue: String

    var body: some View {
        List(AppLanguage.displayOptions) { language in
            Button {
                appLanguageValue = language.rawValue
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.title)
                            .foregroundStyle(.primary)
                        Text(language.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedLanguage == language {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("App Language")
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageValue) ?? .system
    }
}
