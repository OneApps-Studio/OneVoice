import Foundation

enum MacAppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case simplifiedChinese

    static let defaultsKey = "appLanguage"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .english: Locale(identifier: "en-US")
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        }
    }
}
