import Foundation

public struct TextInsertionTarget: Sendable, Hashable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

public enum TextInsertionOutcome: Sendable, Equatable {
    case insertedDirectly
    case pastedFromClipboard
    case copiedToClipboard
    case blockedSecureField
    case failed(String)
}

@MainActor
public protocol TextInsertion: AnyObject {
    func captureTarget() -> TextInsertionTarget?
    func insert(
        _ text: String,
        into target: TextInsertionTarget?
    ) async -> TextInsertionOutcome
}
