import OneVoiceCore
import Testing

@Suite("Transcript normalizer")
struct TranscriptNormalizerTests {
    @Test("Custom dictionary replacements are applied case-insensitively")
    func customDictionary() {
        let normalizer = TranscriptNormalizer(replacements: [
            .init(spoken: "one voice", written: "OneVoice"),
            .init(spoken: "g p t", written: "GPT"),
        ])

        #expect(normalizer.normalize("  ONE VOICE uses g p t  ") == "OneVoice uses GPT")
    }

    @Test("Empty dictionary entries are ignored")
    func emptyReplacementIgnored() {
        let normalizer = TranscriptNormalizer(replacements: [
            .init(spoken: "", written: "bad"),
        ])

        #expect(normalizer.normalize("  hello  ") == "hello")
    }
}
