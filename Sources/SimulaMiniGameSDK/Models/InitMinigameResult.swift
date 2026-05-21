import Foundation

/// Successful `POST /minigames/init` payload used to load the playable iframe + later ad fallback.
public struct InitMinigameResult: Sendable, Equatable {
    public var iframeURL: URL
    public var adId: String?
    public var serveId: String?

    public init(iframeURL: URL, adId: String? = nil, serveId: String? = nil) {
        self.iframeURL = iframeURL
        self.adId = adId
        self.serveId = serveId
    }
}
