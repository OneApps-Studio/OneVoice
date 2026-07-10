# Reusable AI Prompt: Isolate Development and Production Apple Apps

Copy the prompt below into any coding AI before it builds, tests, installs, or packages a macOS/iOS app that may coexist with a production copy.

---

You are working on an Apple-platform app where the developer may keep the production app installed while running Debug builds. Prevent Debug, UI tests, and local probes from colliding with the production app's identity, permissions, data, or installation.

Project values:

- Brand: `<BRAND>`
- Production bundle ID: `<BASE_BUNDLE_ID>`
- Production app name: `<BRAND>`
- Development bundle ID: `<BASE_BUNDLE_ID>.dev`
- Development app name: `<BRAND> Dev`
- Production Application Support folder: `<BRAND>`
- Development Application Support folder: `<BRAND> Dev`
- Production install path: `/Applications/<BRAND>.app`
- Development install path, if installation is required: `/Applications/<BRAND> Dev.app`

Implement and verify all of the following:

1. Give Debug and Release different identities.
   - Release must keep `<BASE_BUNDLE_ID>` and product/display name `<BRAND>`.
   - Debug must use `<BASE_BUNDLE_ID>.dev` and product/display name `<BRAND> Dev`.
   - Unit-test and UI-test bundles must also have unique bundle IDs.
   - If the project is generated, change the source configuration and regenerate it; do not patch only the generated Xcode project.

2. Make the visible names configuration-driven.
   - `CFBundleDisplayName` and `CFBundleName` should expand `$(PRODUCT_NAME)` or equivalent build settings.
   - Debug menus, windows, About panels, login-item labels, and other shell UI should visibly say `<BRAND> Dev`.
   - Release UI must continue to say `<BRAND>`.
   - Prefer a visibly distinct Dev icon or badge when the project already supports per-configuration assets.

3. Isolate all mutable state.
   - Use separate Application Support, caches, temporary files, UserDefaults suites, model downloads, databases, logs, and saved UI state.
   - Isolate Keychain access groups, App Groups, iCloud containers, push environments, URL schemes, background agents, login items, and notification identifiers when those capabilities exist.
   - Never let automated tests write to or delete production data.

4. Protect macOS TCC permissions.
   - Never launch an Apple Development-signed or ad-hoc Debug binary using the production bundle ID.
   - Never overwrite `/Applications/<BRAND>.app` with a Debug build.
   - Treat Accessibility, Input Monitoring, Microphone, Speech Recognition, Screen Recording, Automation, and Local Network grants as bound to the app's code identity.
   - Do not use broad `tccutil reset` commands. A targeted reset is allowed only when the user explicitly approves it.
   - Keep the Release bundle ID and Developer ID signing identity stable across upgrades so existing grants can persist.

5. Keep release signing clean.
   - Use hardened runtime and the intended Developer ID identity.
   - Release must not contain `com.apple.security.get-task-allow`.
   - Do not claim notarization unless Gatekeeper or Apple's notary service confirms it.
   - Do not copy signing keys, profiles, model weights, DerivedData, or release artifacts into source control.

6. Update test-host paths after changing the Debug product name.
   - Unit tests that use `TEST_HOST`/`BUNDLE_LOADER` must point to `<BRAND> Dev.app` in Debug and `<BRAND>.app` in Release.
   - UI tests must launch the Debug bundle ID and must not attach to the installed production app.

7. Verify with current-state evidence, not assumptions.
   - Print Debug and Release `PRODUCT_NAME` and `PRODUCT_BUNDLE_IDENTIFIER` from actual build settings.
   - Build both configurations and inspect their `Info.plist` files.
   - Confirm Debug produces `<BRAND> Dev.app`; Release produces `<BRAND>.app`.
   - Confirm their Application Support paths differ.
   - Run unit/UI tests and the full relevant schemes.
   - Verify the final Release app with `codesign --verify --deep --strict`, inspect entitlements, and run Gatekeeper assessment.
   - Report the exact paths, bundle IDs, signing identities, test results, and any remaining user-authorized permission step.

Before changing files, inspect the repository's `AGENTS.md`, project generator, signing settings, Info plists, entitlements, test-host configuration, persistence paths, login-item code, and current Git status. Preserve unrelated user changes. Commit only the scoped implementation after tests pass.

Do not declare completion merely because both apps compile. Completion requires proof that Debug and Release can coexist without sharing identity, TCC grants, mutable data, or install paths.

---
