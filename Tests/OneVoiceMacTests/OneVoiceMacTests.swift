import Testing
@testable import OneVoiceMac

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
