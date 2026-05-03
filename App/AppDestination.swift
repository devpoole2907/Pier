import Foundation

/// Top-level destinations in the app. Used as the binding value for `TabView` so the selection is
/// type-safe (per `views.md`: prefer enum values over integer/string tags).
enum AppDestination: String, Hashable, CaseIterable, Identifiable {
    case containers
    case stacks
    case images
    case stats
    case settings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .containers: "Containers"
        case .stacks: "Stacks"
        case .images: "Images"
        case .stats: "Stats"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .containers: "shippingbox.fill"
        case .stacks: "square.stack.3d.up.fill"
        case .images: "photo.stack.fill"
        case .stats: "chart.line.uptrend.xyaxis"
        case .settings: "gear"
        }
    }
}
