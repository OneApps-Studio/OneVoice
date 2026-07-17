import SwiftUI

struct SettingsLanguageView: View {
    @Binding var appLanguageValue: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            OnePageBackground()

            ScrollView {
                OneSection(title: "App Language") {
                    ForEach(AppLanguage.displayOptions) { language in
                        SettingsSelectionRow(
                            systemImage: "globe",
                            iconColor: nil,
                            title: language.title,
                            subtitle: language.subtitle,
                            isSelected: selectedLanguage == language
                        ) {
                            appLanguageValue = language.rawValue
                        }

                        if language != AppLanguage.displayOptions.last {
                            OneDivider()
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
        .navigationTitle("App Language")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageValue) ?? .system
    }
}
