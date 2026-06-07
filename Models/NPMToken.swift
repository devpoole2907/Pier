@preconcurrency import Foundation

/// JWT response from `POST /api/tokens` or `GET /api/tokens`.
struct NPMToken: Sendable, Decodable {
    let token: String
    let expires: String?
}
