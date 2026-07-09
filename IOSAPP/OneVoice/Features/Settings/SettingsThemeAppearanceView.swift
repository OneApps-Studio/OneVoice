import SwiftUI

struct SettingsThemeAppearanceView: View {
    @Binding var appAppearanceValue: String
    @Binding var appThemeValue: String

    var body: some View {
        Form {
            Section("Appearance") {
                ForEach(AppAppearance.allCases) { appearance in
                    Button {
                        appAppearanceValue = appearance.rawValue
                    } label: {
                        HStack {
                            Label(appearance.title, systemImage: appearance.icon)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedAppearance == appearance {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Color theme") {
                ForEach(OneAppTheme.allCases) { theme in
                    Button {
                        appThemeValue = theme.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            HStack(spacing: -5) {
                                ForEach(Array(theme.swatches.enumerated()), id: \.offset) { _, color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 24, height: 24)
                                        .overlay { Circle().stroke(.white.opacity(0.8), lineWidth: 1) }
                                }
                            }
                            .frame(width: 60, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.title)
                                    .foregroundStyle(.primary)
                                Text(theme.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Theme & Appearance")
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceValue) ?? .system
    }

    private var selectedTheme: OneAppTheme {
        OneAppTheme(rawValue: appThemeValue) ?? .defaultTheme
    }
}
