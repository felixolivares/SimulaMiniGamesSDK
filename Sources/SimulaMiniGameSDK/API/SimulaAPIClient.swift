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
}
