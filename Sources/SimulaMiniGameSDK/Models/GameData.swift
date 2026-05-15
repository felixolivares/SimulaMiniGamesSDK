import Foundation

/// Mirrors `GameData` from the React SDK.
public struct GameData: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var iconUrl: URL?
    public var description: String
    public var iconFallback: String?
    public var gifCover: URL?

    public init(
        id: String,
        name: String,
        iconUrl: URL?,
        description: String,
        iconFallback: String? = nil,
        gifCover: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.iconUrl = iconUrl
        self.description = description
        self.iconFallback = iconFallback
        self.gifCover = gifCover
    }
}
