import OneAppsShell
import SwiftUI

struct SettingsView: View {
    let model: OneVoiceMobileModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.oneAppTheme) private var theme
    @AppStorage(AppStorageKeys.appLanguage) private var appLanguageValue = AppLanguage.system.rawValue
    @AppStorage(AppStorageKeys.appAppearance) private var appAppearanceValue = AppAppearance.system.rawValue
    @AppStorage(AppStorageKeys.appTheme) private var appThemeValue = OneAppTheme.defaultTheme.rawValue
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = true

    private let catalog = try? OneAppsCatalog.bundled()

    var body: some View {
        ZStack {
            OnePageBackground()

            ScrollView {
                OneSectionStack(spacing: OneStyle.sectionSpacing) {
                    recognitionSection
                    QwenModelSettingsSection(model: model)
                    iCloudSection
                    preferencesSection
                    privacySection
                    aboutSection
                    moreAppsSection
                    helpSection
                    versionFooter
                }
                .padding(.horizontal, OneStyle.screenHorizontalPadding)
                .padding(.top, OneStyle.rootContentTopSpacing)
                .padding(.bottom, 112)
                .frame(maxWidth: OneStyle.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: SettingsDestination.self) { destination in
            switch destination {
            case .language:
                SettingsLanguageView(appLanguageValue: $appLanguageValue)
            case .themeAndAppearance:
                SettingsThemeAppearanceView(
                    appAppearanceValue: $appAppearanceValue,
                    appThemeValue: $appThemeValue
                )
            case .dataPrivacy:
                OneVoiceDataPrivacyView()
            case .about:
                OneVoiceAboutView()
            }
        }
    }

    private var recognitionSection: some View {
        OneSection(title: "Recognition") {
            Menu {
                Picker("Language", selection: Bindable(model).localeIdentifier) {
                    Text("简体中文").tag("zh-Hans")
                    Text("English (US)").tag("en-US")
                    Text("日本語").tag("ja-JP")
                }
            } label: {
                OneRow(
                    systemImage: "character.bubble",
                    title: "Recognition Language"
                ) {
                    Text(recognitionLanguageName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            OneDivider()

            OneRow(
                systemImage: "waveform.badge.mic",
                title: "Live Recognition"
            ) {
                Text("Apple On-Device")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var iCloudSection: some View {
        OneSection(title: "iCloud Sync") {
            Toggle(
                isOn: Binding(
                    get: { model.iCloudSyncEnabled },
                    set: { model.setICloudSyncEnabled($0) }
                )
            ) {
                OneRow(
                    systemImage: "icloud",
                    title: "Sync Library",
                    subtitle: "Recordings, transcripts, and dictionary"
                )
            }
            .toggleStyle(.switch)
            .padding(.trailing, 16)

            OneDivider()

            OneRow(systemImage: "checkmark.icloud", title: "Status") {
                Text(iCloudStatusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            OneDivider()

            Button {
                model.refreshCloudSync()
            } label: {
                OneRow(systemImage: "arrow.triangle.2.circlepath", title: "Sync Now") {
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.iCloudSyncEnabled)
        }
    }

    private var preferencesSection: some View {
        OneSection(title: "Preferences") {
            NavigationLink(value: SettingsDestination.language) {
                OneRow(systemImage: "globe", title: "App Language") {
                    Text(selectedAppLanguage.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            OneDivider()

            NavigationLink(value: SettingsDestination.themeAndAppearance) {
                OneRow(systemImage: "paintpalette", title: "Theme & Appearance") {
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var privacySection: some View {
        OneSection(title: "Data & Privacy") {
            NavigationLink(value: SettingsDestination.dataPrivacy) {
                OneRow(
                    systemImage: "lock.shield",
                    title: "Privacy Promise",
                    subtitle: "Local-first. No account, ads, or analytics."
                ) {
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var aboutSection: some View {
        OneSection(title: "About") {
            NavigationLink(value: SettingsDestination.about) {
                OneRow(systemImage: "info.circle", title: "About OneVoice") {
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var moreAppsSection: some View {
        if let catalog {
            OneSection(title: "More From One Apps") {
                OneAppsCatalogLink(
                    catalog: catalog,
                    currentAppID: "onevoice",
                    style: OneAppsCatalogStyle(
                        background: theme.backgroundBottom,
                        surface: theme.elevatedSurface,
                        primaryAccent: theme.primaryAccent,
                        secondaryAccent: theme.secondaryAccent
                    )
                )
            }
        }
    }

    private var helpSection: some View {
        OneSection(title: "Help") {
            Button {
                hasCompletedOnboarding = false
            } label: {
                OneRow(systemImage: "sparkles.rectangle.stack", title: "Show Onboarding Again")
            }
            .buttonStyle(.plain)
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 7) {
            Text("OneVoice \(appVersion)")
                .font(.footnote.bold())
            Text("Copyright © One Apps Studio")
                .font(.footnote)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var recognitionLanguageName: LocalizedStringResource {
        switch model.localeIdentifier {
        case "en-US": "English (US)"
        case "ja-JP": "日本語"
        default: "简体中文"
        }
    }

    private var selectedAppLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageValue) ?? .system
    }

    private var iCloudStatusText: LocalizedStringResource {
        switch model.iCloudSyncStatus {
        case .disabled: "Off"
        case .syncing: "Syncing…"
        case .synced: "Synced"
        case .unavailable: "iCloud unavailable"
        case .failed: "Sync error"
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2"
    }
}

enum SettingsDestination: Hashable {
    case language
    case themeAndAppearance
    case dataPrivacy
    case about
}

#Preview {
    NavigationStack {
        SettingsView(model: .shared)
    }
}
