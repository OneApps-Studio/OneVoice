# Releasing OneVoice

> This document records the final standalone release process. Active releases now come from the private One Apps Studio monorepo; do not publish new versions from this archived repository.

OneVoice uses five release surfaces with separate responsibilities:

- Private monorepo `OneApps-Studio/OneApps`: canonical development source, release configuration, and future history.
- Archived public repository `OneApps-Studio/OneVoice`: the final standalone source snapshot and migration notice. It is not a development remote.
- GitHub Releases on the standalone repository: frozen version record and an additional binary download for the final standalone release.
- Cloudflare R2 bucket `oneapps-studio-assets`: primary binary mirror behind `downloads.oneapps.studio`.
- App Store Connect: the signed iOS/iPadOS build, metadata, review, and phased release state.

The One Apps Studio product page is maintained separately and should link to the immutable R2 download URL.

## Versioning

Use semantic versions and matching annotated Git tags: `v1.0.0`, `v1.1.0`, and `v1.2.0`.

Create a tag only after the final app and DMG pass all release checks. Never move an existing release tag and never replace a versioned R2 object. If an artifact changes, increment the version. New development tags belong to the monorepo; the standalone repository is frozen after its final migration release.

## Required release checks

1. Confirm that the source tree is clean and `MARKETING_VERSION` matches the intended tag.
2. Generate the project with `xcodegen generate`.
3. Run `swift test` in `Packages/OneVoiceKit`.
4. Build and test both `OneVoice` and `OneVoiceMac` schemes.
5. Build the macOS Release app with Developer ID signing and hardened runtime.
6. Verify that the release entitlements do not contain `com.apple.security.get-task-allow`.
7. Submit the app to Apple's notary service, staple the accepted ticket, and validate it.
8. Create and Developer ID sign the DMG, notarize it, staple it, and validate it.
9. Mount the final DMG and verify the contained app with `codesign`, `stapler`, and Gatekeeper.
10. Compute SHA-256 from the final stapled DMG.

Do not publish a stable release unless both the app and DMG report `source=Notarized Developer ID` under Gatekeeper assessment.

## iOS and CloudKit release

1. Keep Debug isolated as `OneVoice Dev` with bundle ID `studio.oneapps.onevoice.dev`; never use a development-signed build with the production identity to test local changes.
2. Run the package tests, iOS unit/UI tests, and the physical-device background-recording test.
3. Verify that leaving OneVoice and locking the device do not stop recording, then confirm the saved `.m4a` is non-empty and playable after relaunch.
4. Verify the private CloudKit development schema and deploy it to production using [cloudkit-schema.md](cloudkit-schema.md).
5. Archive the `OneVoice` scheme in Release, export with `IOSAPP/Config/ExportOptions-AppStore.plist`, and validate the exported entitlements.
6. Upload the build, wait for processing, attach it to the matching App Store version, complete privacy/encryption/age-rating declarations, and run the App Store Connect submission-readiness checks.
7. Submit only after the final screenshots, localized metadata, review contact, and background-audio review note are present.

The review note must explain that background audio is user-initiated voice-note recording: recording begins only after the user taps the microphone, remains visibly active, and stops when the user taps Finish or Cancel. OneVoice does not start recording silently.

## R2 layout

Versioned objects are immutable and cached for one year:

```text
onevoice/releases/v1.0.0/OneVoice-1.0.0.dmg
onevoice/releases/v1.0.0/OneVoice-1.0.0.sha256
onevoice/releases/v1.0.0/release.json
```

The channel pointer is mutable and uses a short cache lifetime:

```text
onevoice/latest.json
```

Publish the versioned objects first. Update `latest.json` only after every immutable object and the GitHub Release are available.

## Publication order

1. Merge and push the release commit in `OneApps-Studio/OneApps`.
2. For the final migration release only, export the matching `Apps/OneVoice` snapshot to `OneApps-Studio/OneVoice`, add the deprecation notice, and tag it.
3. Create the GitHub Release and attach the DMG and checksum before archiving the standalone repository.
4. Upload the same DMG, checksum, and release manifest to their versioned R2 keys.
5. Verify the public objects by downloading and hashing the DMG.
6. Update `latest.json`.
7. Update and deploy the One Apps Studio product page and download button.
8. Archive `OneApps-Studio/OneVoice` after the monorepo release, public artifacts, and migration notice are all verifiable.

Signing certificates, App Store Connect keys, Cloudflare credentials, notarization profiles, model weights, and release artifacts must remain outside Git.
