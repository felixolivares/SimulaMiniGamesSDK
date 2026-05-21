import Foundation

enum APIConstants {
    static let baseURL = URL(string: "https://simula-api-701226639755.us-central1.run.app")!
}

enum SimulaSDKError: LocalizedError {
    case invalidAPIKey
    case httpStatus(Int)
    case invalidResponse
    case sessionCreationFailed
    /// No `sessionId` after bootstrap — required for playable + ad lifecycle calls.
    case missingSession

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key (please check dashboard or contact Simula team for a valid API key)"
        case .httpStatus(let code):
            return "HTTP error: \(code)"
        case .invalidResponse:
            return "Unexpected response from server"
        case .sessionCreationFailed:
            return "Could not create session"
        case .missingSession:
            return "No Simula session is available yet"
        }
    }
}
