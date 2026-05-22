import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit
#endif

/// Hosts **`iframe_url`** from Simula APIs (playable shell + fallback interstitial) or the aggregated **`/widget/shell`** document.
///
/// Implements a Mobile Safari-like user agent (**`WKWebView`** defaults are occasionally under-filled by GPT / Ad wrappers).
///
/// **Ad click-through:** many creatives use **`window.open`** / **`target="_blank"`**. Without **`WKUIDelegate`**, those navigations are dropped and buttons look inert. We open **`http`/`https`** destinations in the system browser (never **`load`** them on the shell **`WKWebView`**, which would replace **`/widget/shell`** and kill the banner). Use **`onDestinationOpen`** to mirror outbound taps for analytics or future JS bridge work.
public struct SimulaIframeWebView: UIViewRepresentable {

    let url: URL
    /// Invoked once after the **first** successful main-frame load (used for publisher **`onImpression`** on the **`/widget/shell`** host).
    var onPrimaryDocumentLoad: (() -> Void)?
    /// User-activated navigation to an **`http`/`https`** URL (in-frame link and pop-up / **`window.open`** paths that we hand off to Safari).
    var onDestinationOpen: ((URL) -> Void)?

    public init(
        url: URL,
        onPrimaryDocumentLoad: (() -> Void)? = nil,
        onDestinationOpen: ((URL) -> Void)? = nil
    ) {
        self.url = url
        self.onPrimaryDocumentLoad = onPrimaryDocumentLoad
        self.onDestinationOpen = onDestinationOpen
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Mobile Safari UA — some GPT / Ad wrappers under-serve generic **`WKWebView`** fingerprints.
    private static func safariLikeMobileUserAgent() -> String {
#if canImport(UIKit)
        let system = UIDevice.current.systemVersion
        let underscored = system.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(underscored) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(system) Mobile/15E148 Safari/604.1"
#else
        return "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
#endif
    }

    public func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true

        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        cfg.defaultWebpagePreferences = pagePrefs

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = Self.safariLikeMobileUserAgent()
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)

        webView.scrollView.keyboardDismissMode = .onDrag

        context.coordinator.onPrimaryDocumentLoad = onPrimaryDocumentLoad
        context.coordinator.onDestinationOpen = onDestinationOpen
        context.coordinator.resetForNewURL(url)
        webView.load(URLRequest(url: url))

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onPrimaryDocumentLoad = onPrimaryDocumentLoad
        context.coordinator.onDestinationOpen = onDestinationOpen
        if context.coordinator.lastLoaded != url {
            context.coordinator.resetForNewURL(url)
            uiView.load(URLRequest(url: url))
        }
    }

    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        fileprivate(set) var lastLoaded: URL?
        var onPrimaryDocumentLoad: (() -> Void)?
        var onDestinationOpen: ((URL) -> Void)?
        private var didFirePrimaryLoad = false

        func resetForNewURL(_ newURL: URL) {
            lastLoaded = newURL
            didFirePrimaryLoad = false
        }

        /// Same-document link taps keep working in-WebView while the host observes the outbound URL (`onDestinationOpen`).
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               navigationAction.targetFrame != nil,
               let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https"
            {
                onDestinationOpen?(url)
            }
            decisionHandler(.allow)
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if !didFirePrimaryLoad {
                didFirePrimaryLoad = true
                onPrimaryDocumentLoad?()
            }
        }

        /// `window.open` / `_blank` — never `load` on the hosting web view (would replace widget shell).
        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil else { return nil }
            guard let url = navigationAction.request.url else { return nil }
            let scheme = url.scheme?.lowercased() ?? ""
            guard scheme == "http" || scheme == "https" else { return nil }
#if canImport(UIKit)
            onDestinationOpen?(url)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
#endif
            return nil
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Self.logLoadFailure(error)
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Self.logLoadFailure(error)
        }

        private static func logLoadFailure(_ error: Error) {
#if DEBUG
            NSLog("SimulaIframeWebView: load failed \(error)")
#endif
        }
    }
}
