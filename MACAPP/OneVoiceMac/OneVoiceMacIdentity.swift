import Foundation

enum OneVoiceMacIdentity {
    enum Variant: Equatable {
        case production
        case development
    }

    static var variant: Variant {
        variant(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? displayName(for: variant)
    }

    static var applicationSupportDirectoryName: String {
        applicationSupportDirectoryName(for: variant)
    }

    static var qwenModelDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        return base
            .appending(path: applicationSupportDirectoryName, directoryHint: .isDirectory)
            .appending(path: "Models", directoryHint: .isDirectory)
            .appending(path: "Qwen3-ASR-0.6B-MLX-4bit", directoryHint: .isDirectory)
    }

    static func variant(bundleIdentifier: String?) -> Variant {
        bundleIdentifier?.hasSuffix(".dev") == true ? .development : .production
    }

    static func displayName(for variant: Variant) -> String {
        switch variant {
        case .production: "OneVoice"
        case .development: "OneVoice Dev"
        }
    }

    static func applicationSupportDirectoryName(for variant: Variant) -> String {
        displayName(for: variant)
    }
}
