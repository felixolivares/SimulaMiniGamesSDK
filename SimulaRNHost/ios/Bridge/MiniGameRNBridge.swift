import Foundation
import SimulaMiniGameSDK

/// Shared **`MiniGameProvider`** for the RN module + **`MiniGameMenuView`** bridged subtree.
///
/// **`configure`** should run once at app startup (before **`MiniGameMenu`** becomes visible).
@MainActor
final class MiniGameRNBridge {

    static let shared = MiniGameRNBridge()

    private init() {}

    /// Replace with **`SimulaAdSDK.configure`** before showing the native menu (placeholder until JS calls **`configure`**).
    private(set) var provider = MiniGameProvider(apiKey: "replaceme_via_configure", devMode: false)

    func configure(apiKey: String, devMode: Bool) {
        provider = MiniGameProvider(apiKey: apiKey, devMode: devMode)
    }
}
