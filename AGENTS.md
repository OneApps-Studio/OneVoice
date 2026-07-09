# OneVoice Agent Guide

DO NOT send optional commentary.

OneVoice is an Apache-2.0 open-source, privacy-first offline dictation app for macOS and iOS.

## Product invariants

- Swift and SwiftUI only at the app layer.
- macOS 26 and iOS 26 are the minimum supported versions because the default recognizer uses `SpeechAnalyzer`.
- Apple on-device Speech provides live transcription.
- Qwen3-ASR 0.6B is an optional user-initiated download and only replaces the final transcript.
- Quick dictation audio is never persisted.
- History and personal dictionary data stay in local Application Support JSON files.
- macOS global shortcuts remain Fn hold-to-talk and Right Command tap-to-toggle.
- Secure fields are never filled automatically.
- Keep all user-facing claims truthful: no account, no analytics, no audio upload.

## Development

- Generate the Xcode project with `xcodegen generate` after changing `project.yml`.
- Run package tests with `cd Packages/OneVoiceKit && swift test`.
- Use a portrait iPhone simulator for primary iOS UI verification.
- Do not commit `build/`, `.build/`, release artifacts, signing material, model weights, or downloaded model caches.
- Keep commits focused and verify both `OneVoice` and `OneVoiceMac` schemes before release.

## Release

- macOS release builds use hardened runtime and Developer ID signing.
- Verify the final `.app`, `.dmg`, and installed `/Applications/OneVoice.app` with `codesign` and Gatekeeper.
- Never claim notarization unless `spctl` or the notary service confirms it.
