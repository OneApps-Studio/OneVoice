import Foundation

enum MainTab: String {
    case record
    case history
    case dictionary
    case settings

    static var initial: MainTab {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let isUITest = environment["ONEVOICE_UI_TEST"] == "1" || argumentValue(for: "ONEVOICE_UI_TEST") == "1"
        guard isUITest else { return .record }

        let rawValue = environment["ONEVOICE_INITIAL_TAB"] ?? argumentValue(for: "ONEVOICE_INITIAL_TAB")
        return rawValue.flatMap(MainTab.init(rawValue:)) ?? .record
        #else
        return .record
        #endif
    }

    #if DEBUG
    private static func argumentValue(for key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        let argumentKey = "-\(key)"

        guard let index = arguments.firstIndex(of: argumentKey) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
    #endif
}
