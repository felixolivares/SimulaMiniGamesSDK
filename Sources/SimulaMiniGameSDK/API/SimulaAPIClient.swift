import Foundation

struct CatalogResponse: Sendable {
    var menuId: String
    var games: [GameData]
}

/// Low-level HTTP client mirroring `src/utils/api.ts` session + catalog calls.
struct SimulaAPIClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func createSession(apiKey: String, devMode: Bool, primaryUserID: String?) async throws -> String {
        var components = URLComponents(url: APIConstants.baseURL.appendingPathComponent("session/create"), resolvingAgainstBaseURL: false)!
        var query: [URLQueryItem] = []
        query.append(URLQueryItem(name: "devMode", value: String(devMode)))
        if let primaryUserID, !primaryUserID.isEmpty {
            query.append(URLQueryItem(name: "ppid", value: primaryUserID))
        }
        components.queryItems = query.isEmpty ? nil : query

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("1", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SimulaSDKError.invalidResponse
        }
        if http.statusCode == 401 {
            throw SimulaSDKError.invalidAPIKey
        }
        guard http.statusCode == 200 else {
            throw SimulaSDKError.httpStatus(http.statusCode)
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sessionId = json["sessionId"] as? String,
            !sessionId.isEmpty
        else {
            throw SimulaSDKError.sessionCreationFailed
        }
        return sessionId
    }

    func fetchCatalog() async throws -> CatalogResponse {
        var request = URLRequest(url: APIConstants.baseURL.appendingPathComponent("minigames/catalogv2"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "ngrok-skip-browser-warning")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SimulaSDKError.httpStatus(code)
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let responseData = jsonObject as? [String: Any] else {
            throw SimulaSDKError.invalidResponse
        }

        let menuId = (responseData["menu_id"] as? String) ?? ""

        let gamesList: [[String: Any]]
        if let catalog = responseData["catalog"] {
            if let arr = catalog as? [[String: Any]] {
                gamesList = arr
            } else if let dict = catalog as? [String: Any], let inner = dict["data"] as? [[String: Any]] {
                gamesList = inner
            } else if let dataArr = responseData["data"] as? [[String: Any]] {
                gamesList = dataArr
            } else {
                gamesList = []
            }
        } else if let dataArr = responseData["data"] as? [[String: Any]] {
            gamesList = dataArr
        } else {
            gamesList = []
        }

        let games: [GameData] = gamesList.compactMap { game in
            guard let id = game["id"] as? String, let name = game["name"] as? String else { return nil }
            let description = (game["description"] as? String) ?? ""
            let icon = (game["icon"] as? String).flatMap { URL(string: $0) }
            let gifCover = (game["gif_cover"] as? String).flatMap { URL(string: $0) }
            let fallback = game["iconFallback"] as? String ?? game["icon_fallback"] as? String
            return GameData(
                id: id,
                name: name,
                iconUrl: icon,
                description: description,
                iconFallback: fallback,
                gifCover: gifCover
            )
        }

        return CatalogResponse(menuId: menuId, games: games)
    }

    func trackMenuGameClick(menuId: String, gameName: String, apiKey: String) async {
        var request = URLRequest(url: APIConstants.baseURL.appendingPathComponent("minigames/menu/track/click"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("1", forHTTPHeaderField: "ngrok-skip-browser-warning")

        let body: [String: String] = [
            "menu_id": menuId,
            "game_name": gameName,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await session.data(for: request)
    }

    /// Initializes the playable minigame shell (`React` **`getMinigame`** → `POST /minigames/init`).
    func initMinigame(
        gameTypeId: String,
        sessionId: String,
        widthPoints: Int,
        heightPoints: Int,
        charId: String,
        charName: String,
        charImage: String?,
        charDesc: String?,
        messages: [MiniGameMessage],
        delegateCharacter: Bool,
        menuId: String?,
        convId: String?,
        entryPoint: String?
    ) async throws -> InitMinigameResult {
        let url = APIConstants.baseURL.appendingPathComponent("minigames/init")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "ngrok-skip-browser-warning")

        var body: [String: Any] = [
            "game_type": gameTypeId,
            "session_id": sessionId,
            "conv_id": convId ?? NSNull(),
            "entry_point": entryPoint ?? NSNull(),
            "currency_mode": false,
            "w": widthPoints,
            "h": heightPoints,
            "char_id": charId,
            "char_name": charName,
            "char_desc": charDesc ?? "",
            "delegate_char": delegateCharacter,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        if let charImage {
            body["char_image"] = charImage
        }
        if let menuId {
            body["menu_id"] = menuId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SimulaSDKError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw SimulaSDKError.httpStatus(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SimulaSDKError.invalidResponse
        }

        let adResponseDict = json["adResponse"] as? [String: Any]
            ?? json["ad_response"] as? [String: Any]

        guard let nested = adResponseDict else {
            throw SimulaSDKError.invalidResponse
        }

        let iframeString = nested["iframe_url"] as? String ?? nested["iframeUrl"] as? String
        guard let iframeString, let iframeURL = URL(string: iframeString) else {
            throw SimulaSDKError.invalidResponse
        }

        let adId = nested["ad_id"] as? String ?? nested["adId"] as? String
        let serveId = nested["serve_id"] as? String ?? nested["serveId"] as? String

        return InitMinigameResult(iframeURL: iframeURL, adId: adId, serveId: serveId)
    }

    func fetchMinigameFallbackAdIframeURL(adId: String, sessionId: String) async throws -> URL? {
        let path = "minigames/fallback_ad/\(adId)"
        var components = URLComponents(url: APIConstants.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "session_id", value: sessionId)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "ngrok-skip-browser-warning")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SimulaSDKError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let adResponseDict = json["adResponse"] as? [String: Any]
            ?? json["ad_response"] as? [String: Any]
        let iframeString = adResponseDict?["iframe_url"] as? String
            ?? adResponseDict?["iframeUrl"] as? String

        guard let iframeString else { return nil }
        return URL(string: iframeString)
    }

    func reportMiniGameAdInterstitial(
        serveId: String,
        sessionId: String,
        adSource: MiniGameAdInterstitialSource,
        renderedFormat: String?
    ) async {
        let pathEncoded = serveId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? serveId
        let url = APIConstants.baseURL.appendingPathComponent("minigames/play/\(pathEncoded)/ad-interstitial")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "ngrok-skip-browser-warning")

        var payload: [String: Any] = [
            "session_id": sessionId,
            "ad_source": adSource.rawValue,
        ]
        if let renderedFormat {
            payload["rendered_format"] = renderedFormat
        } else {
            payload["rendered_format"] = NSNull()
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await session.data(for: request)
    }
}
