import SwiftUI

/// A single addressable Komodo terminal target — a server, container, stack, or deployment the
/// user can open a live terminal against (see `KomodoTerminalConnection` and `KomodoTerminalView`).
struct KomodoTerminalTarget: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Identifiable {
        case server
        case container
        case stack
        case deployment

        var id: String { rawValue }

        var label: String {
            switch self {
            case .server: "Server"
            case .container: "Container"
            case .stack: "Stack"
            case .deployment: "Deployment"
            }
        }

        var pluralLabel: String {
            switch self {
            case .server: "Servers"
            case .container: "Containers"
            case .stack: "Stacks"
            case .deployment: "Deployments"
            }
        }

        var systemImage: String {
            switch self {
            case .server: "server.rack"
            case .container: "shippingbox"
            case .stack: "square.stack.3d.up"
            case .deployment: "arrow.up.forward.app"
            }
        }
    }

    /// Whether a container-like terminal execs a fresh shell or attaches to the container's
    /// existing entrypoint process. Not meaningful for `.server` targets.
    enum Mode: String, CaseIterable, Identifiable {
        case exec
        case attach

        var id: String { rawValue }

        var label: String {
            switch self {
            case .exec: "Exec"
            case .attach: "Attach"
            }
        }
    }

    let kind: Kind
    let resourceID: String
    let name: String
    let subtitle: String

    /// The server a Container target lives on. Required (alongside `name`, the container's Docker
    /// name) to build the terminal websocket URL's `target[params][server]` — Container is the
    /// only kind whose Komodo API params need more than the resource's own id.
    var serverID: String? = nil

    /// The compose service to attach to for a Stack target's `target[params][service]`.
    /// Typically the stack's first service; empty if the stack has none.
    var serviceName: String? = nil

    /// Exec vs attach, for `.container`/`.stack`/`.deployment` targets.
    var mode: Mode = .exec

    /// Optional user-chosen name for the `terminal=` query param; falls back to a hardcoded
    /// default (`"pier"`) when nil/empty.
    var terminalName: String? = nil

    var id: String { "\(kind.rawValue):\(resourceID)" }
}
