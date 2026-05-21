import Foundation

/// Mirrors React `Message` for minigame `init` requests.
public struct MiniGameMessage: Sendable {
    public var role: String
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}
