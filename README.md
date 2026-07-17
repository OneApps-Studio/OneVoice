# OneVoice

> [!IMPORTANT]
> This repository is archived. OneVoice development moved into the One Apps Studio monorepo after version 1.2.0. This repository preserves the final public source snapshot and release artifacts; issues and pull requests are no longer maintained here.

OneVoice is a native Swift app for private, offline speech-to-text on macOS and iPhone.

On macOS, hold **Fn** to talk or tap **Right Command** to start and stop recording. OneVoice shows a live transcript and inserts the final text into the focused field in most apps. On iPhone, it records voice notes, shows live transcription, and keeps searchable local history.

## Download

- [Download OneVoice 1.2.0 for macOS](https://downloads.oneapps.studio/onevoice/releases/v1.2.0/OneVoice-1.2.0.dmg)
- [Verify SHA-256](https://downloads.oneapps.studio/onevoice/releases/v1.2.0/OneVoice-1.2.0.dmg.sha256)
- [Release metadata](https://downloads.oneapps.studio/onevoice/releases/v1.2.0/release.json)

The downloadable macOS build is Developer ID signed, notarized by Apple, and distributed as an Apple-silicon DMG.

## Highlights

- Apple `SpeechAnalyzer` for fast on-device live transcription
- Optional Qwen3-ASR 0.6B 4-bit final pass for higher accuracy
- Global macOS Fn and Right Command gestures
- Accessibility insertion with safe clipboard fallback
- Searchable history and a personal pronunciation dictionary
- English and Simplified Chinese UI on iOS and macOS
- Background voice-note recording on iPhone and iPad with automatic searchable transcripts
- Private iCloud sync for voice-note audio, transcripts, and personal dictionary across Apple devices
- No OneVoice account, analytics, proprietary audio server, or quick-dictation audio storage

## Requirements

- Apple silicon Mac with macOS 26 or newer
- iOS/iPadOS 26 or newer
- Xcode 26.5 or newer
- Apple silicon for Qwen3-ASR inference
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```bash
cd IOSAPP
xcodegen generate
cd ..

# Shared package tests
cd Packages/OneVoiceKit
swift test
cd ../..

# macOS
xcodebuild -project IOSAPP/OneVoice.xcodeproj -scheme OneVoiceMac \
  -destination 'platform=macOS,arch=arm64' build

# iOS Simulator
xcodebuild -project IOSAPP/OneVoice.xcodeproj -scheme OneVoice \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

This frozen snapshot keeps the monorepo-relative `OneAppsKit` dependency used by the 1.2.0 release. It is retained for source and history reference rather than ongoing standalone development.

The Qwen model is not bundled in the repository or app. Users explicitly download the pinned 0.6B model from Hugging Face. Downloaded weights live under Application Support and are excluded from iCloud backup.

## Development identity isolation

macOS Debug builds are intentionally named **OneVoice Dev** and use bundle ID `studio.oneapps.onevoice.mac.dev` plus `Application Support/OneVoice Dev`. Release builds remain **OneVoice**, use `studio.oneapps.onevoice.mac`, and store data under `Application Support/OneVoice`. Never run a development-signed build with the production bundle ID: mixing signing identities under one ID can invalidate macOS privacy permissions for the installed release app.

## macOS permissions

OneVoice explains and requests four permissions:

- Microphone — capture voice
- Speech Recognition — run Apple's on-device recognizer
- Input Monitoring — detect Fn and Right Command globally
- Accessibility — insert text into the focused field

Secure text fields are never filled automatically. If a target cannot be edited safely, OneVoice copies the transcript instead.

## Project layout

```text
IOSAPP/                 iPhone and iPad SwiftUI app
MACAPP/                 macOS menu-bar app and global insertion
Packages/OneVoiceKit/   shared domain, Apple Speech, and Qwen adapters
ThirdParty/Qwen3Speech/ vendored minimal speech-swift subset
Tests/                  Xcode unit and UI tests
Design/                 app-icon master artwork
```

See [docs/architecture.md](docs/architecture.md), [docs/privacy.md](docs/privacy.md), and [docs/cloudkit-schema.md](docs/cloudkit-schema.md) for implementation details.

Release maintainers should also read [docs/releasing.md](docs/releasing.md).

## License

OneVoice is licensed under Apache-2.0. The vendored Qwen3Speech subset retains its upstream Apache-2.0 license and attribution.
