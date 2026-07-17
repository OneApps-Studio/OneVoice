import SwiftUI

struct OneVoiceDataPrivacyView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            OnePageBackground()

            ScrollView {
                OneSectionStack(spacing: OneStyle.sectionSpacing) {
                    OneSection(title: "Privacy Promise") {
                        OneRow(
                            systemImage: "iphone",
                            title: "Local-First",
                            subtitle: "Recording and transcription start on your device, without a OneVoice account."
                        )
                        OneDivider()
                        OneRow(
                            systemImage: "eye.slash",
                            title: "No Ads or Analytics",
                            subtitle: "OneVoice does not include an analytics SDK or third-party tracking."
                        )
                        OneDivider()
                        OneRow(
                            systemImage: "server.rack",
                            title: "No OneVoice Audio Server",
                            subtitle: "Your voice is never uploaded to a server operated by OneVoice or One Apps Studio."
                        )
                    }

                    OneSection(title: "Private iCloud") {
                        OneRow(
                            systemImage: "icloud",
                            title: "Your Apple Account",
                            subtitle: "When sync is on, voice-note audio, transcripts, and dictionary entries mirror through your private iCloud database."
                        )
                        OneDivider()
                        OneRow(
                            systemImage: "square.and.arrow.down",
                            title: "Imports Stay Temporary",
                            subtitle: "Imported audio and video are transcribed on this device and are not added to your OneVoice library or iCloud."
                        )
                        OneDivider()
                        OneRow(
                            systemImage: "internaldrive",
                            title: "Models Stay on Device",
                            subtitle: "The optional Qwen model is downloaded only when you request it and never syncs."
                        )
                    }

                    OneSection(title: "Policy") {
                        Link(destination: URL(string: "https://oneapps.studio/privacy")!) {
                            OneRow(systemImage: "hand.raised", title: "Privacy Policy") {
                                Image(systemName: "arrow.up.right")
                                    .font(.footnote.bold())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, OneStyle.screenHorizontalPadding)
                .padding(.top, OneStyle.rootContentTopSpacing)
                .padding(.bottom, 48)
                .frame(maxWidth: OneStyle.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.large)
    }
}
