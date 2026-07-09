import Foundation

public struct TranscriptNormalizer: Sendable {
    private let replacements: [DictionaryReplacement]

    public init(replacements: [DictionaryReplacement] = []) {
        self.replacements = replacements
    }

    public func normalize(_ transcript: String) -> String {
        var result = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        for replacement in replacements where !replacement.spoken.isEmpty {
            result = result.replacingOccurrences(
                of: replacement.spoken,
                with: replacement.written,
                options: [.caseInsensitive, .literal]
            )
        }
        return result
    }
}
