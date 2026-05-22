import Foundation

/// Publisher-facing **`onImpression`** payload fired when the **`/widget/shell`** HTML document completes its first successful load inside the playable **`WKWebView`** (includes the configured top-banner slot layout when **`showBanner`** is true — same surface as **`WidgetShell`** on web).
///
/// Note: Inner Aditude creatives may hydrate after this milestone; finer **OMID** / slot-level parity can augment this in bridge Task 2 if needed.
public struct MiniGameShellImpressionContext: Sendable, Equatable {
    public var placement: String
    public var gameTypeId: String
    public var gameName: String
    public var serveId: String?
    public var adId: String?
    public var showBanner: Bool

    public init(
        placement: String,
        gameTypeId: String,
        gameName: String,
        serveId: String?,
        adId: String?,
        showBanner: Bool
    ) {
        self.placement = placement
        self.gameTypeId = gameTypeId
        self.gameName = gameName
        self.serveId = serveId
        self.adId = adId
        self.showBanner = showBanner
    }
}
