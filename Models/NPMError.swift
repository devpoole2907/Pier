import Foundation

enum NPMError: Error, LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case notFound
    case serverError(code: Int, message: String?)
    case network(URLError)
    case decoding(String)
    case missingCredentials

    static func from(_ error: Error) -> NPMError {
        if let npmError = error as? NPMError {
            return npmError
        }
        if let urlError = error as? URLError {
            return .network(urlError)
        }
        return .serverError(code: -1, message: error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The NPM host URL is not valid."
        case .unauthorized:
            "Authentication failed. Check your credentials."
        case .notFound:
            "The requested resource was not found."
        case .serverError(let code, let message):
            "Server error \(code)\(message.map { ": \($0)" } ?? "")."
        case .network(let urlError):
            "Network error: \(urlError.localizedDescription)"
        case .decoding(let detail):
            "Could not decode the response: \(detail)"
        case .missingCredentials:
            "No credentials available for this NPM host."
        }
    }
}
