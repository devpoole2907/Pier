import SwiftUI

extension ContainerStatus {
    /// SwiftUI color used for badges and dots. Resolves to the system semantic colors so dark mode works.
    var color: Color {
        switch self {
        case .running: .green
        case .restarting, .paused: .yellow
        case .stopped, .exited, .created: .secondary
        case .dead: .red
        case .removing: .orange
        case .unknown: .gray
        }
    }

    /// SF Symbol that matches the state for use in `Image(systemName:)`.
    var symbolName: String {
        switch self {
        case .running: "play.circle.fill"
        case .restarting: "arrow.clockwise.circle.fill"
        case .paused: "pause.circle.fill"
        case .stopped, .exited: "stop.circle.fill"
        case .created: "circle.dashed"
        case .dead: "xmark.octagon.fill"
        case .removing: "trash.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    /// Localised human-readable name suitable for badges.
    var displayName: String {
        rawValue.capitalized
    }
}
