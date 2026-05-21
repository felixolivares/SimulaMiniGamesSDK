import Foundation

/// Values accepted by **`/minigames/play/{serveId}/ad-interstitial`** (`reportAdInterstitial` in React).
public enum MiniGameAdInterstitialSource: String, Sendable {
    case simula
    case aditude
    case none
}
