import Foundation

/// All errors surfaced by `PortainerClient`. Conforms to `LocalizedError` so views can present friendly messages.
enum PortainerError: Error, LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case notFound
    case serverError(code: Int, message: String?)
    case network(URLError)
    case decoding(String)
    case missingCredentials
    case streamClosed

    static func from(_ error: Error) -> PortainerError {
        if let portainerError = error as? PortainerError {
            return portainerError
        }
        if let urlError = error as? URLError {
            return .network(urlError)
        }
        return .serverError(code: -1, message: error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The Portainer host URL is not valid."
        case .unauthorized:
            "Authentication failed. Check your username and password."
        case .notFound:
            "The requested resource was not found."
        case .serverError(let code, let message):
            "Server error \(code)\(message.map { ": \($0)" } ?? "")."
        case .network(let urlError):
            "Network error: \(urlError.localizedDescription)"
        case .decoding(let detail):
            "Could not decode the response: \(detail)"
        case .missingCredentials:
            "No credentials available for this host."
        case .streamClosed:
            "The stream was closed."
        }
    }
}
