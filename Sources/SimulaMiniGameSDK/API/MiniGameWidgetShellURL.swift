import Foundation

/// Builds the same **`/widget/shell`** URL the React **`WidgetShell`** iframe uses so the native shell (and top banner) match web.
///
/// **`domain`** is **not** a bundle identifier: Aditude mounts `<script async src="https://htlbid.com/v3/<domain>/htlbid.js">`.
/// Reverse-DNS **`com.publisher.app`** identifiers return **`503`** and the **50 px banner slot stays empty** (often read as plain black band).
enum MiniGameWidgetShellURL {

    /// Default **`domain`** for the publicly documented **`pub_eeee…`** sample key + catalog (paired with **`coolaigames.com`** HTLB config).
    static let playgroundDefaultBannerDomain = "coolaigames.com"

    /// - Parameters:
    ///   - publisherAdDomain: Overrides **`domain`** (**`htlbid.com/v3/<domain>/`** bootstrap). Omit to use **`MiniGameWidgetShellURL.playgroundDefaultBannerDomain`** after ignoring non-HTLB playable hosts (see **`resolvePublisherDomain`**).
    ///   - devMode: Passed through as **`dev`**. **`dev=true`** **disables Aditude refreshes entirely** inside the shell (black banner slot unless placeholders are added server-side).
    static func gameShellURL(
        gamePlayableURL: URL,
        publisherAdDomain: String?,
        showBanner: Bool,
        devMode: Bool
    ) -> URL {
        var components = URLComponents(
            url: APIConstants.baseURL.appendingPathComponent("widget/shell"),
            resolvingAgainstBaseURL: false
        )!
        let domain = Self.resolvePublisherDomain(
            explicitPublisherDomain: publisherAdDomain,
            gameIframeHost: gamePlayableURL.host
        )
        let parentOrigin = "app://simula-minigame-sdk"
        components.queryItems = [
            URLQueryItem(name: "variant", value: "game"),
            URLQueryItem(name: "domain", value: domain),
            URLQueryItem(name: "game_url", value: gamePlayableURL.absoluteString),
            URLQueryItem(name: "show_banner", value: showBanner ? "true" : "false"),
            URLQueryItem(name: "dev", value: devMode ? "true" : "false"),
            URLQueryItem(name: "parent_origin", value: parentOrigin),
        ]
        return components.url!
    }

    static func resolvePublisherDomain(
        explicitPublisherDomain: String?,
        gameIframeHost: String?
    ) -> String {
        if let host = sanitizedWebHostname(from: explicitPublisherDomain) {
            return host
        }
        // `iframe_url` often lives on a CDN / game host that is **not** the Aditude site key embedded in
        // `https://htlbid.com/v3/<domain>/htlbid.js`. Using that host typically yields **503** and a blank banner.
        if let host = sanitizedWebHostname(from: gameIframeHost), hostMightShareHTLBConfigWithPlayground(host) {
            return host
        }
#if DEBUG
        NSLog(
            "SimulaMiniGameSDK: Banner domain → \(playgroundDefaultBannerDomain) " +
                "(iframe host \(gameIframeHost ?? "nil") is not used as HTLB site key; set `publisherAdDomain` for your property)."
        )
#endif
        return playgroundDefaultBannerDomain
    }

    /// When **`publisherAdDomain`** is omitted, only trust **`iframe_url`** hosts that plausibly match the configured HTLB bucket (assessment games ship on **`coolaigames.com`**).
    private static func hostMightShareHTLBConfigWithPlayground(_ host: String) -> Bool {
        host == playgroundDefaultBannerDomain || host.hasSuffix(".\(playgroundDefaultBannerDomain)")
    }

    /// Accepts **`coolaigames.com`**, **`https://publisher.example/path`**, or **`www.publisher.example`**; rejects **`localhost`** / obvious non-host strings.
    private static func sanitizedWebHostname(from raw: String?) -> String? {
        guard var trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        if trimmed.contains("://") {
            guard let parsed = URL(string: trimmed), let host = parsed.host else { return nil }
            trimmed = host
        } else if trimmed.contains("/"), let parsed = URL(string: "https://\(trimmed)"), let host = parsed.host {
            trimmed = host
        }

        trimmed = trimmed.lowercased()
        if trimmed.hasPrefix("www.") {
            trimmed = String(trimmed.dropFirst(4))
        }

        if trimmed.isEmpty || trimmed == "localhost" || trimmed.starts(with: "127.") || trimmed.contains(" ") {
            return nil
        }

        guard isLikelyHTLBPublisherHostname(trimmed) else {
            return nil
        }

        return trimmed
    }

    /// **HTLB** paths look like **`/v3/coolaigames.com/`** — we require a plausible DNS-shaped hostname (**`.`** + valid labels).
    private static func isLikelyHTLBPublisherHostname(_ host: String) -> Bool {
        // Basic registrable-shape guard (not full WHATWG parsing).
        let pattern = #"^(?!-)(?:[a-z0-9-]{1,63}\.)+(?!-)[a-z0-9-]{2,63}$"#
        return host.range(of: pattern, options: .regularExpression) != nil
    }
}
