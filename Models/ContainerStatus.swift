import Foundation

/// Normalized container state. Maps from Docker's freeform `state` strings.
enum ContainerStatus: String, Codable, Sendable, CaseIterable, Comparable {
    case running
    case stopped
    case paused
    case restarting
    case dead
    case created
    case exited
    case removing
    case unknown

    init(rawState: String) {
        self = ContainerStatus(rawValue: rawState.lowercased()) ?? .unknown
    }

    /// Sort priority: running first, then transient states, then stopped/dead last.
    var sortRank: Int {
        switch self {
        case .running: 0
        case .restarting, .paused: 1
        case .created: 2
        case .stopped, .exited: 3
        case .removing: 4
        case .dead: 5
        case .unknown: 6
        }
    }

    static func < (lhs: ContainerStatus, rhs: ContainerStatus) -> Bool {
        lhs.sortRank < rhs.sortRank
    }
}
