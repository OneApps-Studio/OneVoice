import SwiftUI

struct OneVoiceAboutView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            OnePageBackground()

            ScrollView {
                OneSectionStack(spacing: OneStyle.sectionSpacing) {
                    appSection
                    studioSection
                    linksSection
                    creditsSection
                    footer
                }
                .padding(.horizontal, OneStyle.screenHorizontalPadding)
                .padding(.top, OneStyle.rootContentTopSpacing)
                .padding(.bottom, 48)
                .frame(maxWidth: OneStyle.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
    }

    private var appSection: some View {
        OneSection(verbatim: "OneVoice") {
            HStack(spacing: 16) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Record, transcribe, remember")
                        .font(.headline)
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private var studioSection: some View {
        OneSection(title: "Studio") {
            OneRow(
                systemImage: "building.2",
                verbatim: "One Apps Studio",
                verbatimSubtitle: String(localized: "Focused apps for everyday work, made with care for privacy and simplicity.")
            )
            OneDivider()
            Link(destination: URL(string: "https://oneapps.studio")!) {
                OneRow(systemImage: "globe", title: "About One Apps") {
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var linksSection: some View {
        OneSection(title: "Links") {
            aboutLinkRow(title: "Product Page", icon: "safari", url: "https://oneapps.studio/apps/onevoice")
            OneDivider()
            aboutLinkRow(title: "Support", icon: "questionmark.circle", url: "https://oneapps.studio/support")
            OneDivider()
            aboutLinkRow(title: "Privacy Policy", icon: "hand.raised", url: "https://oneapps.studio/privacy")
            OneDivider()
            aboutLinkRow(title: "Contact", icon: "envelope", url: "mailto:contact@oneapps.studio")
            OneDivider()
            aboutLinkRow(title: "Source Code", icon: "chevron.left.forwardslash.chevron.right", url: "https://github.com/OneApps-Studio/OneVoice")
        }
    }

    private var creditsSection: some View {
        OneSection(title: "Open Source") {
            aboutLinkRow(title: "Qwen3-ASR", icon: "brain.head.profile", url: "https://github.com/QwenLM/Qwen3-ASR")
            OneDivider()
            aboutLinkRow(title: "MLX Swift", icon: "cpu", url: "https://github.com/ml-explore/mlx-swift")
        }
    }

    private var footer: some View {
        Text("Copyright © One Apps Studio")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    private func aboutLinkRow(title: LocalizedStringResource, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            OneRow(systemImage: icon, title: title) {
                Image(systemName: "arrow.up.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "4"
    }
}
