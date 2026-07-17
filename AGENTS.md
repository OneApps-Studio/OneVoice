# OneVoice Agent Guide

DO NOT send optional commentary.

OneVoice is an Apache-2.0 open-source, privacy-first offline dictation app for macOS and iOS.

## Product invariants

- Swift and SwiftUI only at the app layer.
- macOS 26 and iOS 26 are the minimum supported versions because the default recognizer uses `SpeechAnalyzer`.
- Apple on-device Speech provides live transcription.
- Qwen3-ASR 0.6B is an optional user-initiated download and only replaces the final transcript.
- Quick dictation audio is never persisted.
- iOS voice notes persist compressed audio locally and continue recording after the app backgrounds. Their audio, transcript metadata, and personal dictionary mirror through the user's private iCloud database by default so the Mac app can play and search them.
- Quick-dictation audio, imported media, and model files never sync. Quick-dictation audio is never persisted.
- macOS global shortcuts remain Fn hold-to-talk and Right Command tap-to-toggle.
- Secure fields are never filled automatically.
- Keep all user-facing claims truthful: no OneVoice account, no analytics, and no OneVoice-operated audio server. When iCloud Sync is enabled, voice-note audio is uploaded only to the user's private Apple iCloud database.

## Development

- Debug builds must remain isolated as `OneVoice Dev`: iOS bundle ID `studio.oneapps.onevoice.dev`, macOS bundle ID `studio.oneapps.onevoice.mac.dev`, product/display name `OneVoice Dev`, and Application Support folder `OneVoice Dev`. Never run an Apple Development-signed build with a production bundle ID or overwrite `/Applications/OneVoice.app` during testing.
- Generate the Xcode project with `cd IOSAPP && xcodegen generate` after changing `IOSAPP/project.yml`.
- Run package tests with `cd Packages/OneVoiceKit && swift test`.
- Use a portrait iPhone simulator for primary iOS UI verification.
- Do not commit `build/`, `.build/`, release artifacts, signing material, model weights, or downloaded model caches.
- Keep commits focused and verify both `OneVoice` and `OneVoiceMac` schemes before release.

## Release

- macOS release builds use hardened runtime and Developer ID signing.
- Verify the final `.app`, `.dmg`, and installed `/Applications/OneVoice.app` with `codesign` and Gatekeeper.
- Never claim notarization unless `spctl` or the notary service confirms it.
