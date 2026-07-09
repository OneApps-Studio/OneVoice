import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese
    case japanese

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .system:
            return "System"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .japanese:
            return "日本語"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .system:
            return "Use device language"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .japanese:
            return "Japanese"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en-US")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .japanese:
            return Locale(identifier: "ja")
        }
    }

    var searchTokens: [String] {
        switch self {
        case .system:
            return ["system", "default", "automatic", "device", "跟随系统", "系统", "自動", "端末"]
        case .english:
            return ["english", "en", "us", "英语", "英文", "英語"]
        case .simplifiedChinese:
            return ["simplified chinese", "chinese", "zh", "zh-hans", "mandarin", "简体中文", "中文", "中国語"]
        case .japanese:
            return ["japanese", "ja", "nihongo", "日语", "日文", "日本語"]
        }
    }

    static var displayOptions: [AppLanguage] {
        [.system] + AppLanguage.allCases
            .filter { $0 != .system }
            .sorted { lhs, rhs in
                lhs.title.key.localizedStandardCompare(rhs.title.key) == .orderedAscending
            }
    }

    func matchesSearch(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }

        return (searchTokens + [locale.identifier])
            .contains { $0.localizedStandardContains(normalized) }
    }

    static var current: AppLanguage {
        let stored = UserDefaults.standard.string(forKey: AppStorageKeys.appLanguage)
        return AppLanguage(rawValue: stored ?? AppLanguage.system.rawValue) ?? .system
    }
}
