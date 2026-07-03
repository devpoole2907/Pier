import Foundation

/// A Komodo global variable, from `/read/ListVariables`. Read-only in Pier; secret values are
/// masked in the UI rather than displayed.
nonisolated struct KomodoVariable: Identifiable, Sendable, Hashable {
    let name: String
    let value: String
    let description: String
    let isSecret: Bool

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name
        case value
        case description
        case isSecret = "is_secret"
    }
}

extension KomodoVariable: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.value = try container.decodeIfPresent(String.self, forKey: .value) ?? ""
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.isSecret = try container.decodeIfPresent(Bool.self, forKey: .isSecret) ?? false
    }
}
