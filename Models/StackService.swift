import Foundation

/// A single service within a stack, joined with its live container (if running), from
/// `/read/ListStackServices`. Lets the UI show per-service container state inside a stack.
nonisolated struct StackService: Sendable, Identifiable, Hashable {
    let service: String
    let image: String
    let container: Container?

    var id: String { service }

    static func == (lhs: StackService, rhs: StackService) -> Bool {
        lhs.service == rhs.service && lhs.image == rhs.image && lhs.container?.id == rhs.container?.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(service)
        hasher.combine(image)
    }

    private enum CodingKeys: String, CodingKey {
        case service
        case image
        case container
    }
}

extension StackService: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.service = try container.decodeIfPresent(String.self, forKey: .service) ?? ""
        self.image = try container.decodeIfPresent(String.self, forKey: .image) ?? ""
        self.container = try container.decodeIfPresent(Container.self, forKey: .container)
    }
}
