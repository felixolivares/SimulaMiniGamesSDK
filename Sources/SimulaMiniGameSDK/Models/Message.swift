import Foundation

/// Chat message stub for parity with `@simula/ads` APIs (hosts may omit when unused).
public struct SimulaChatMessage: Hashable, Sendable, Codable {
    public var role: String
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}
