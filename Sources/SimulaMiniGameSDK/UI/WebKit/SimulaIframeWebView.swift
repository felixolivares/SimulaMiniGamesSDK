import SwiftUI
import WebKit

/// Hosts **`iframe_url`** from Simula APIs (playable shell + fallback interstitial).
public struct SimulaIframeWebView: UIViewRepresentable {

    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)

        webView.scrollView.keyboardDismissMode = .onDrag

        webView.load(URLRequest(url: url))
        context.coordinator.lastLoaded = url

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.lastLoaded != url {
            context.coordinator.lastLoaded = url
            uiView.load(URLRequest(url: url))
        }
    }

    public final class Coordinator: NSObject, WKNavigationDelegate {
        fileprivate(set) var lastLoaded: URL?

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
