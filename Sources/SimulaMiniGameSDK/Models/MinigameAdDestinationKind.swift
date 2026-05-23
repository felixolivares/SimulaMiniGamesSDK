import Foundation

/// Per-game hint from **`catalogv2`** for how click-throughs for that title are expected to behave.
///
/// **`fetchCatalog`** maps **`destination_type`** when present; otherwise it infers from URL fields on the row. When still **`unknown`**, click routing should inspect the actual tap **`URL`** (e.g. **`apps.apple.com`** → StoreKit).
public enum MinigameAdDestinationKind: String, Sendable, Hashable, Codable {
    case appStore
    case web
    case unknown
}

extension MinigameAdDestinationKind {
    /// Maps common API string shapes (snake / kebab / synonyms).
    public static func parsingAPIValue(_ raw: String?) -> MinigameAdDestinationKind {
        guard let raw, !raw.isEmpty else { return .unknown }
        let n = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch n {
        case "app", "application", "app_store", "appstore", "store", "ios_app", "mobile_app":
            return .appStore
        case "web", "website", "url", "http", "landing":
            return .web
        default:
            return .unknown
        }
    }

    /// When **`catalogv2`** omits **`destination_type`**, infer from known URL-ish fields (**`url`**, **`cta_url`**, …).
    ///
    /// **`appStore`**: **`itms-apps`**, **`itms`**, or host **`apps.apple.com`** / **`itunes.apple.com`** (matching click routing).
    /// **`web`**: first **`http`/`https`** URL that is not classified as App Store.
    /// Otherwise **`unknown`**.
    public static func inferringFromCatalogRowURLs(_ urls: [URL]) -> MinigameAdDestinationKind {
        guard !urls.isEmpty else { return .unknown }

        for url in urls {
            guard simulaIndicatesAppStoreHostOrScheme(url) else { continue }
            return .appStore
        }

        for url in urls {
            let scheme = url.scheme?.lowercased() ?? ""
            guard scheme == "http" || scheme == "https" else { continue }
            guard !simulaIndicatesAppStoreHostOrScheme(url) else { continue }
            return .web
        }

        return .unknown
    }

    /// Collects plausible destination URL strings from a raw **`catalogv2`** row.
    static func catalogRowURLCandidates(from row: [String: Any]) -> [URL] {
        let keys = [
            "url", "destination_url", "destinationUrl", "link",
            "app_store_url", "appStoreUrl", "cta_url", "ctaUrl",
            "store_url", "storeUrl", "redirect_url", "redirectUrl",
        ]
        var seen = Set<String>()
        var urls: [URL] = []
        urls.reserveCapacity(keys.count)

        for key in keys {
            guard let raw = row[key] as? String else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard seen.insert(trimmed.lowercased()).inserted else { continue }
            if let url = URL(string: trimmed) {
                urls.append(url)
            }
        }

        return urls
    }

    /// **`true`** if routing should prefer App Store / StoreKit semantics for this **`url`** (aligns with host **`SKStoreProductViewController`** shim).
    public static func simulaIndicatesAppStoreHostOrScheme(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "itms-apps" || scheme == "itms" {
            return true
        }
        let host = url.host?.lowercased() ?? ""
        return host.contains("apps.apple.com") || host.contains("itunes.apple.com")
    }
}
