import SwiftUI

struct OneVoiceOnboardingPage: View {
    let step: OneVoiceOnboardingStep

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 0)

                    if step.showsLogo {
                        Image("BrandMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 23))
                            .shadow(radius: 20, y: 10)
                            .accessibilityLabel("OneVoice")
                    } else {
                        Image(systemName: step == .accurate ? "waveform.badge.magnifyingglass" : "text.bubble.fill")
                            .font(.system(size: 58, weight: .medium))
                            .foregroundStyle(.tint)
                            .frame(width: 92, height: 92)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    }

                    Text(step.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text(step.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    VStack(spacing: 12) {
                        ForEach(features, id: \.icon) { feature in
                            HStack(spacing: 16) {
                                Image(systemName: feature.icon)
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                    .frame(width: 46, height: 46)
                                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feature.title).font(.headline)
                                    Text(feature.note)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(16)
                            .oneCard()
                        }
                    }

                    if step.showsStudioFooter {
                        Text("by OneApps.Studio")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, OneStyle.screenHorizontalPadding)
                .padding(.vertical, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
        }
    }

    private var features: [(icon: String, title: LocalizedStringResource, note: LocalizedStringResource)] {
        switch step {
        case .privateSpeech:
            [
                ("iphone", "On-device by design", "Your recordings and history stay on this device."),
                ("waveform", "Live transcription", "Watch words appear as you speak."),
                ("lock.shield", "No account required", "Open the app and start talking."),
            ]
        case .accurate:
            [
                ("bolt.fill", "Apple live preview", "Fast feedback with system on-device speech."),
                ("cpu", "Qwen3-ASR final pass", "Optional 0.6B model for more accurate offline text."),
                ("network.slash", "Works offline", "After download, no network is needed for recognition."),
            ]
        case .ready:
            [
                ("mic.fill", "Tap to record", "Capture short thoughts or longer voice notes."),
                ("text.book.closed", "Teach your terms", "Correct names and specialist vocabulary."),
                ("square.and.arrow.up", "Use it anywhere", "Copy or share the transcript into any app."),
            ]
        }
    }
}
