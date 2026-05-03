import Foundation

/// User-facing refresh interval choices for live data.
enum RefreshInterval: Int, CaseIterable, Identifiable, Sendable, Codable {
    case off = 0
    case fast = 5
    case medium = 10
    case slow = 30

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .fast: "5 seconds"
        case .medium: "10 seconds"
        case .slow: "30 seconds"
        }
    }

    var seconds: TimeInterval? {
        rawValue == 0 ? nil : TimeInterval(rawValue)
    }
}

/// Theme preference for the app.
enum AppTheme: String, CaseIterable, Identifiable, Sendable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
