import SwiftUI

/// A single addressable Komodo terminal target — a server, container, stack, or deployment the
/// user can open a terminal against. Scaffolding only: opening one currently presents
/// `KomodoTerminalPlaceholderView` rather than a live connection (see that file for the intended
/// follow-up implementation).
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

    let kind: Kind
    let resourceID: String
    let name: String
    let subtitle: String

    var id: String { "\(kind.rawValue):\(resourceID)" }
}
