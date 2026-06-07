@preconcurrency import Foundation

struct NPMUser: Sendable, Decodable, Identifiable {
    let id: Int
    let name: String
    let nickname: String?
    let email: String
    let is_disabled: FlexibleBool?
    let roles: [String]?
}
