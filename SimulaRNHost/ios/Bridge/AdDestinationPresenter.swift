import Foundation
import SafariServices
import SimulaMiniGameSDK
import StoreKit
import UIKit

enum AdDestinationRoute {
    case storeProduct(itunesItemID: String)
    case safari(URL)
}

enum AdDestinationRouter {

    /// Host routing for ad click‑through URLs. **`catalogHint`** may be inferred from catalog URL fields; otherwise **`url`** is inspected (**`apps.apple.com`**, **`itms-apps`**, … → StoreKit when an iTunes id is present).
    static func route(for context: MiniGameAdDestinationContext) -> AdDestinationRoute {
        route(url: context.url, catalogHint: context.resolvedDestinationHint)
    }

    static func route(url: URL, catalogHint: MinigameAdDestinationKind?) -> AdDestinationRoute {
        switch catalogHint {
        case .appStore:
            return ITunesRouting.fromAppStoreURLs(url)
        case .web:
            return .safari(url)
        case .unknown, nil:
            break
        }

        if MinigameAdDestinationKind.simulaIndicatesAppStoreHostOrScheme(url) {
            return ITunesRouting.fromAppStoreURLs(url)
        }
        return .safari(url)
    }
}

private enum ITunesRouting {
    /// Returns **`storeProduct`** only when **`url`** exposes a numeric **`/id`** segment (or **`id`** query); otherwise attribution links open in‑app Safari.
    static func fromAppStoreURLs(_ url: URL) -> AdDestinationRoute {
        if let id = ITunesItemIDParser.numericID(from: url) {
            return .storeProduct(itunesItemID: id)
        }
        return .safari(url)
    }
}

private enum ITunesItemIDParser {
    static func numericID(from url: URL) -> String? {
        if let r = url.path.range(of: #"/id(\d{5,})"#, options: .regularExpression) {
            let segment = url.path[r]
            return String(segment.dropFirst("/id".count))
        }

        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        for item in comps.queryItems ?? [] where item.name.caseInsensitiveCompare("id") == .orderedSame {
            guard let raw = item.value, !raw.isEmpty, raw.allSatisfy(\.isNumber), raw.count >= 5 else { continue }
            return raw
        }
        return nil
    }
}

@MainActor
enum AdDestinationPresenter {

    static func present(context: MiniGameAdDestinationContext, from presenter: UIViewController) {
        func presentSafari(_ u: URL) {
            let safari = SFSafariViewController(url: u)
            safari.dismissButtonStyle = .close
            presenter.present(safari, animated: true)
        }

        switch AdDestinationRouter.route(for: context) {
        case .safari(let url):
            presentSafari(url)

        case .storeProduct(let itemId):
            let store = SKStoreProductViewController()
            store.loadProduct(withParameters: [
                SKStoreProductParameterITunesItemIdentifier: itemId,
            ]) { loaded, error in
                Task { @MainActor in
                    if loaded && error == nil {
                        presenter.present(store, animated: true)
                    } else {
                        presentSafari(context.url)
                    }
                }
            }
        }
    }
}
