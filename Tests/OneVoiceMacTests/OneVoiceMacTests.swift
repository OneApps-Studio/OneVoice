import Testing
@testable import OneVoiceMac

@Suite("Development identity isolation")
struct DevelopmentIdentityIsolationTests {
    @Test("Development identity cannot collide with production identity or data")
    func developmentIdentityIsIsolated() {
        let production = OneVoiceMacIdentity.variant(
            bundleIdentifier: "studio.oneapps.onevoice.mac"
        )
        let development = OneVoiceMacIdentity.variant(
            bundleIdentifier: "studio.oneapps.onevoice.mac.dev"
        )

        #expect(production == .production)
        #expect(development == .development)
        #expect(OneVoiceMacIdentity.displayName(for: production) == "OneVoice")
        #expect(OneVoiceMacIdentity.displayName(for: development) == "OneVoice Dev")
        #expect(OneVoiceMacIdentity.applicationSupportDirectoryName(for: production) == "OneVoice")
        #expect(OneVoiceMacIdentity.applicationSupportDirectoryName(for: development) == "OneVoice Dev")
    }
}

@Suite("Safe text insertion policy")
struct SafeTextInsertionPolicyTests {
    @Test("Regular editable roles are allowed when no secure subrole exists")
    func allowsKnownEditableRole() {
        #expect(MacTextInsertion.classify(role: "AXTextArea", subrole: .absent) == .allowed)
        #expect(MacTextInsertion.classify(role: "AXTextField", subrole: .value("AXSearchField")) == .allowed)
    }

    @Test("Secure and unreadable fields fail closed")
    func blocksProtectedOrUnknownFields() {
        #expect(MacTextInsertion.classify(role: "AXTextField", subrole: .value("AXSecureTextField")) == .secure)
        #expect(MacTextInsertion.classify(role: "AXTextField", subrole: .unreadable) == .unverified)
        #expect(MacTextInsertion.classify(role: "AXGroup", subrole: .absent) == .unverified)
        #expect(MacTextInsertion.classify(role: "AXTextField", subrole: .value("UnexpectedSubrole")) == .unverified)
    }
}

@Suite("Configurable global shortcuts")
struct ConfigurableGlobalShortcutTests {
    @Test("Defaults remain Fn hold and Right Command tap")
    func defaultsMatchProductContract() {
        #expect(GlobalHotkeyKey.defaultPushToTalk == .function)
        #expect(GlobalHotkeyKey.defaultToggle == .rightCommand)
    }

    @Test("Every selectable modifier has a unique physical key code")
    func selectableKeysAreUnambiguous() {
        let keyCodes = GlobalHotkeyKey.allCases.map(\.keyCode)
        #expect(Set(keyCodes).count == keyCodes.count)
    }

    @Test("Conflict fallback always selects a different key")
    func conflictFallbackIsDifferent() {
        for key in GlobalHotkeyKey.allCases {
            #expect(GlobalHotkeyKey.fallback(excluding: key, preferred: key) != key)
        }
    }
}
