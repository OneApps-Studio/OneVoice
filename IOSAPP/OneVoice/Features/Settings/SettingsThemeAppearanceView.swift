import SwiftUI

struct SettingsThemeAppearanceView: View {
    @Binding var appAppearanceValue: String
    @Binding var appThemeValue: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            OnePageBackground()

            ScrollView {
                OneSectionStack(spacing: OneStyle.sectionSpacing) {
                    OneSection(title: "Theme") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(OneAppTheme.allCases) { theme in
                                SettingsThemeOptionRow(
                                    appTheme: theme,
                                    isSelected: selectedTheme == theme
                                ) {
                                    appThemeValue = theme.rawValue
                                }
                            }
                        }
                        .padding(16)
                    }

                    OneSection(title: "Appearance") {
                        ForEach(AppAppearance.allCases) { appearance in
                            SettingsSelectionRow(
                                systemImage: appearance.icon,
                                iconColor: nil,
                                title: appearance.title,
                                isSelected: selectedAppearance == appearance
                            ) {
                                appAppearanceValue = appearance.rawValue
                            }

                            if appearance != AppAppearance.allCases.last {
                                OneDivider()
                            }
                        }
                    }
                }
                .padding(.horizontal, OneStyle.screenHorizontalPadding)
                .padding(.top, OneStyle.rootContentTopSpacing)
                .padding(.bottom, 32)
                .frame(maxWidth: OneStyle.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Theme & Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceValue) ?? .system
    }

    private var selectedTheme: OneAppTheme {
        OneAppTheme(rawValue: appThemeValue) ?? .defaultTheme
    }
}
