@preconcurrency import Foundation

/// NPM's write endpoints validate boolean fields as JSON `true`/`false` (ajv, `type: boolean`).
/// This wrapper decodes flexibly from `Bool`, `Int` (0/1), or numeric `String` for response compatibility,
/// and encodes as a native JSON boolean so create/update requests pass schema validation.
struct FlexibleBool: Sendable, Hashable {
    let value: Bool
}

extension FlexibleBool {
    var boolValue: Bool { value }
}

extension FlexibleBool: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) {
        self.value = value
    }
}

extension FlexibleBool: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int != 0
        } else if let string = try? container.decode(String.self), let int = Int(string) {
            self.value = int != 0
        } else {
            throw DecodingError.typeMismatch(
                FlexibleBool.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Bool, Int, or numeric String"
                )
            )
        }
    }
}

extension FlexibleBool: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
