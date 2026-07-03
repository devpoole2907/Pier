import SwiftUI

enum PierServiceIdentity: String, CaseIterable, Identifiable {
    case komodo
    case nginxProxyManager
    case ssh

    var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .komodo: "Komodo"
        case .nginxProxyManager: "Nginx Proxy Manager"
        case .ssh: "SSH"
        }
    }

    var brandColor: Color {
        switch self {
        case .komodo: DesignSystem.Colors.accent
        case .nginxProxyManager: DesignSystem.Colors.npm
        case .ssh: .green
        }
    }

    nonisolated var systemImage: String {
        switch self {
        case .komodo: "server.rack"
        case .nginxProxyManager: "arrow.triangle.branch"
        case .ssh: "terminal.fill"
        }
    }

    nonisolated var tabSystemImage: String {
        switch self {
        case .komodo: "server.rack"
        case .nginxProxyManager: "arrow.triangle.branch"
        case .ssh: "terminal"
        }
    }
}
