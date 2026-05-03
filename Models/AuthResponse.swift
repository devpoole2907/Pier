import Foundation

/// Response from `POST /api/auth`. Portainer returns `{ "jwt": "..." }`.
struct AuthResponse: Sendable {
    let jwt: String

    private enum CodingKeys: String, CodingKey {
        case jwt
    }
}

extension AuthResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.jwt = try container.decode(String.self, forKey: .jwt)
    }
}
