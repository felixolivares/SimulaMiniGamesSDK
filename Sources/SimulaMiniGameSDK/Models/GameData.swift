import Foundation

/// Mirrors `GameData` from the React SDK.
public struct GameData: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var iconUrl: URL?
    public var description: String
    public var iconFallback: String?
    public var gifCover: URL?
    /// Hint from **`catalogv2`** — **`destination_type`** / synonyms when present, else inferred from **`url`**‑like fields (**`apps.apple.com`** → **`appStore`**, other **`http`/`https`** → **`web`**).
    public var adDestinationKind: MinigameAdDestinationKind

    public init(
        id: String,
        name: String,
        iconUrl: URL?,
        description: String,
        iconFallback: String? = nil,
        gifCover: URL? = nil,
        adDestinationKind: MinigameAdDestinationKind = .unknown
    ) {
        self.id = id
        self.name = name
        self.iconUrl = iconUrl
        self.description = description
        self.iconFallback = iconFallback
        self.gifCover = gifCover
        self.adDestinationKind = adDestinationKind
    }
}

extension GameData {

    /// One-line snapshot of **`GameData`** after **`catalogv2`** mapping (mirrors Xcode diagnostics; use from JS **`debugPeekCatalogMappedSummary`** for Metro).
    public var debugMappedCatalogSummaryLine: String {
        let icon = iconUrl?.absoluteString ?? "nil"
        let gif = gifCover?.absoluteString ?? "nil"
        let fb = iconFallback ?? "nil"
        let snippet = description.replacingOccurrences(of: "\n", with: "\\n").prefix(100)
        let ellipses = description.count > 100 ? "…" : ""
        return "id=\(id) name=\(name) adDestinationKind=\(adDestinationKind.rawValue) descriptionLen=\(description.count) snippet=\"\(snippet)\(ellipses)\" icon=\(icon) gif=\(gif) iconFallback=\(fb)"
    }
}
