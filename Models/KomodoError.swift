import Foundation

/// All errors surfaced by `KomodoClient`. Conforms to `LocalizedError` so views can present friendly messages.
nonisolated enum KomodoError: Error, LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case notFound
    case serverError(code: Int, message: String?)
    case network(URLError)
    case decoding(String)
    case apiKeyMissing
    case streamClosed

    static func from(_ error: Error) -> KomodoError {
        if let komodoError = error as? KomodoError {
            return komodoError
        }
        if error is CancellationError {
            return .streamClosed
        }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled {
                return .streamClosed
            }
            return .network(urlError)
        }
        return .serverError(code: -1, message: error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The Komodo Core URL is not valid."
        case .unauthorized:
            "Authentication failed. Check the API key and secret."
        case .notFound:
            "The requested resource was not found."
        case .serverError(let code, let message):
            "Server error \(code)\(message.map { ": \($0)" } ?? "")."
        case .network(let urlError):
            "Network error: \(urlError.localizedDescription)"
        case .decoding(let detail):
            "Could not decode the response: \(detail)"
        case .apiKeyMissing:
            "No API key/secret available for this host."
        case .streamClosed:
            "The stream was closed."
        }
    }
}
