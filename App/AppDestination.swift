import Foundation

/// Top-level destinations in the app. Used as the binding value for `TabView` so the selection is
/// type-safe (per `views.md`: prefer enum values over integer/string tags).
enum AppDestination: String, Hashable, CaseIterable, Identifiable {
    case dashboard
    case containers
    case terminals
    case proxy
    case more

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dashboard: "Dashboard"
        case .containers: "Containers"
        case .terminals: "Terminals"
        case .proxy: "Proxy"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2.fill"
        case .containers: "shippingbox.fill"
        case .terminals: "terminal.fill"
        case .proxy: "arrow.triangle.branch"
        case .more: "ellipsis.circle"
        }
    }
}
