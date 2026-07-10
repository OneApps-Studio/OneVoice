# Releasing OneVoice

OneVoice uses three release surfaces with separate responsibilities:

- GitHub repository `OneApps-Studio/OneVoice`: source, issues, tags, and release notes.
- GitHub Releases: canonical version record and an additional binary download.
- Cloudflare R2 bucket `oneapps-studio-assets`: primary binary mirror behind `downloads.oneapps.studio`.

The One Apps Studio product page is maintained separately and should link to the immutable R2 download URL.

## Versioning

Use semantic versions and matching annotated Git tags: `v1.0.0`, `v1.0.1`, and `v1.1.0`.

Create a tag only after the final app and DMG pass all release checks. Never move an existing release tag and never replace a versioned R2 object. If an artifact changes, increment the version.

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

1. Push the release commit.
2. Create and push the annotated tag.
3. Create the GitHub Release and attach the DMG and checksum.
4. Upload the same DMG, checksum, and release manifest to their versioned R2 keys.
5. Verify the public objects by downloading and hashing the DMG.
6. Update `latest.json`.
7. Update the One Apps Studio product page and download button.

Signing certificates, App Store Connect keys, Cloudflare credentials, notarization profiles, model weights, and release artifacts must remain outside Git.
