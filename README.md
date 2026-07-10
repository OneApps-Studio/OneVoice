# OneVoice

OneVoice is a native Swift app for private, offline speech-to-text on macOS and iPhone.

On macOS, hold **Fn** to talk or tap **Right Command** to start and stop recording. OneVoice shows a live transcript and inserts the final text into the focused field in most apps. On iPhone, it records voice notes, shows live transcription, and keeps searchable local history.

## Highlights

- Apple `SpeechAnalyzer` for fast on-device live transcription
- Optional Qwen3-ASR 0.6B 4-bit final pass for higher accuracy
- Global macOS Fn and Right Command gestures
- Accessibility insertion with safe clipboard fallback
- Searchable history and a personal pronunciation dictionary
- English, Simplified Chinese, and Japanese UI on iOS
- No account, analytics, audio upload, or quick-dictation audio storage

## Requirements

- macOS 26 or newer
- iOS/iPadOS 26 or newer
- Xcode 26.5 or newer
- Apple silicon for Qwen3-ASR inference
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```bash
xcodegen generate

# Shared package tests
cd Packages/OneVoiceKit
swift test
cd ../..

# macOS
xcodebuild -project OneVoice.xcodeproj -scheme OneVoiceMac \
  -destination 'platform=macOS,arch=arm64' build

# iOS Simulator
xcodebuild -project OneVoice.xcodeproj -scheme OneVoice \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

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

See [docs/architecture.md](docs/architecture.md) and [docs/privacy.md](docs/privacy.md) for implementation details.

## License

OneVoice is licensed under Apache-2.0. The vendored Qwen3Speech subset retains its upstream Apache-2.0 license and attribution.
