import Foundation

/// Delivered alongside **`MiniGameMenuView`** **`onDestinationOpen`** so native hosts can route ads with catalog context (**`focusedGame`** is non-**`nil`** during playable + exit interstitial when a game was selected).
public struct MiniGameAdDestinationContext: Sendable {
    public let url: URL
    public let focusedGame: GameData?

    public init(url: URL, focusedGame: GameData?) {
        self.url = url
        self.focusedGame = focusedGame
    }

    /// Catalog hint from **`focusedGame`** when meaningful; otherwise derived from **`url`** ( **`apps.apple.com`**, **`itms`**, **`http/https`** ).
    ///
    /// Prefer this when surfacing **`catalogDestinationHint`** — the playable shell link may omit App Store URLs from **`catalogv2`** rows (`GameData` stays **`unknown`** until tap).
    public var resolvedDestinationHint: MinigameAdDestinationKind {
        let catalog = focusedGame?.adDestinationKind ?? .unknown
        if catalog != .unknown {
            return catalog
        }
        return MinigameAdDestinationKind.inferringFromCatalogRowURLs([url])
    }
}
