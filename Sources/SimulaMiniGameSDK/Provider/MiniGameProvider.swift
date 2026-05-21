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
    ///   - devMode: Mirrors React `SimulaProvider` devMode for session creation.
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
