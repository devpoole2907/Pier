import Foundation

/// Top-level destinations in the app. Used as the binding value for `TabView` so the selection is
/// type-safe (per `views.md`: prefer enum values over integer/string tags).
enum AppDestination: String, Hashable, CaseIterable, Identifiable {
    case containers
    case proxy
    case stacks
    case ssh
    case more

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .containers: "Containers"
        case .proxy: "Proxy"
        case .stacks: "Stacks"
        case .ssh: "SSH"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .containers: "shippingbox.fill"
        case .proxy: "arrow.triangle.branch"
        case .stacks: "square.stack.3d.up.fill"
        case .ssh: "terminal.fill"
        case .more: "ellipsis.circle"
        }
    }
}
