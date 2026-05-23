import Foundation
import SwiftUI

@MainActor
public final class MiniGameProvider: ObservableObject {

    public let apiKey: String
    public let devMode: Bool

    /// Server session identifier once `ensureSession` succeeds.
    @Published public private(set) var sessionId: String?

    @Published public private(set) var catalog: CatalogPayload?

    @Published public private(set) var isLoadingCatalog: Bool = false
    @Published public private(set) var catalogError: Error?

    private let api: SimulaAPIClient

    /// - Parameters:
    ///   - apiKey: Publisher API key (`Authorization: Bearer`).
    ///   - devMode: Mirrors React `SimulaProvider` **`devMode`** for session **`createSession`** and the playable **`widget/shell`** (**`dev=true`** skips all in-shell **`tude.refreshAdsViaDivMappings`** calls, so the top banner slot renders empty/black).
    public init(apiKey: String, devMode: Bool = false) {
        self.apiKey = apiKey
        self.devMode = devMode
        self.api = SimulaAPIClient()
    }

    /// Test hook with a custom URL session (kept internal).
    init(apiKey: String, devMode: Bool, apiClient: SimulaAPIClient) {
        self.apiKey = apiKey
        self.devMode = devMode
        self.api = apiClient
    }

    /// Creates or refreshes the server session (`createSession` in `@simula/ads`).
    public func ensureSession(primaryUserID: String? = nil, hasPrivacyConsent: Bool = true) async throws {
        let ppid = hasPrivacyConsent ? primaryUserID : nil
        let id = try await api.createSession(apiKey: apiKey, devMode: devMode, primaryUserID: ppid)
        sessionId = id
    }

    /// Fire-and-forget session bootstrap matching `SimulaProvider` mount behavior (surfaces failures only via `nil` session).
    public func bootstrapSession(primaryUserID: String? = nil, hasPrivacyConsent: Bool = true) async {
        do {
            try await ensureSession(primaryUserID: primaryUserID, hasPrivacyConsent: hasPrivacyConsent)
        } catch {
            sessionId = nil
        }
    }

    /// Loads the catalog (`fetchCatalog`).
    public func loadCatalog(force: Bool = false) async {
        if isLoadingCatalog { return }
        if catalog != nil, !force { return }

        isLoadingCatalog = true
        catalogError = nil
        defer { isLoadingCatalog = false }

        do {
            let response = try await api.fetchCatalog()
            catalog = CatalogPayload(menuId: response.menuId, games: response.games)
            catalogError = nil
        } catch {
            catalog = nil
            catalogError = error
        }
    }

    /// Text snapshot of **`catalog`** mapped to **`[GameData]`** for **`console.log`** via the RN **`SimulaAdSDK.debugPeekCatalogSummary`** shim.
    ///
    /// Prefer this over **`print`** from Pods: Xcode shows native **`stdout`**; Metro only receives JavaScript logs.
    public func debugPeekCatalogMappedSummary() -> String {
        guard let catalog else {
            if let catalogError {
                return "[SimulaMiniGameSDK] catalog is nil (load failed): \(catalogError.localizedDescription)"
            }
            return "[SimulaMiniGameSDK] catalog is nil — call **`loadCatalog`** first."
        }
        var lines = [
            "[SimulaMiniGameSDK] mapped catalog menu_id=\"\(catalog.menuId)\" gameCount=\(catalog.games.count) (Swift `print` in SimulaMiniGameSDK also logs to Xcode; use this string in JS for Metro)."
        ]
        lines += catalog.games.enumerated().map { "[SimulaMiniGameSDK] [\($0.offset)] \($0.element.debugMappedCatalogSummaryLine)" }
        return lines.joined(separator: "\n")
    }

    /// Best-effort menu click beacon (matches React `trackMenuGameClick`).
    public func notifyMenuGameSelected(menuId: String, gameName: String) async {
        await api.trackMenuGameClick(menuId: menuId, gameName: gameName, apiKey: apiKey)
    }

    /// Loads the playable minigame iframe + ad identifiers (`React` **`getMinigame`**).
    public func bootstrapPlayableMinigame(
        gameTypeId: String,
        viewportWidth: Int,
        viewportHeight: Int,
        characterId: String,
        characterName: String,
        characterImageURL: URL?,
        characterDescription: String?,
        messages: [MiniGameMessage] = [],
        delegateCharacterInGame: Bool = true,
        menuId: String?,
        conversationId: String? = nil,
        entryPoint: String? = nil
    ) async throws -> InitMinigameResult {
        guard let sessionId else {
            throw SimulaSDKError.missingSession
        }

        let charPic = characterImageURL?.absoluteString
        return try await api.initMinigame(
            gameTypeId: gameTypeId,
            sessionId: sessionId,
            widthPoints: max(320, viewportWidth),
            heightPoints: max(320, viewportHeight),
            charId: characterId,
            charName: characterName,
            charImage: charPic,
            charDesc: characterDescription,
            messages: messages,
            delegateCharacter: delegateCharacterInGame,
            menuId: menuId,
            convId: conversationId,
            entryPoint: entryPoint
        )
    }

    public func fetchPostGameInterstitialURL(adId: String) async throws -> URL? {
        guard let sessionId else {
            throw SimulaSDKError.missingSession
        }
        return try await api.fetchMinigameFallbackAdIframeURL(adId: adId, sessionId: sessionId)
    }

    /// Best-effort beacon matching React `reportAdInterstitial`.
    public func reportMiniGameAdInterstitial(
        serveId: String?,
        adSource: MiniGameAdInterstitialSource,
        renderedFormat: String? = nil
    ) async {
        guard let sessionId else { return }
        guard let serveId, !serveId.isEmpty else { return }

        await api.reportMiniGameAdInterstitial(
            serveId: serveId,
            sessionId: sessionId,
            adSource: adSource,
            renderedFormat: renderedFormat
        )
    }
}

public struct CatalogPayload: Sendable {
    public var menuId: String
    public var games: [GameData]

    public init(menuId: String, games: [GameData]) {
        self.menuId = menuId
        self.games = games
    }
}
