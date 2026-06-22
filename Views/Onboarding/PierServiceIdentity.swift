import SwiftUI

enum PierServiceIdentity: String, CaseIterable, Identifiable {
    case portainer
    case nginxProxyManager
    case ssh

    var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .portainer: "Portainer"
        case .nginxProxyManager: "Nginx Proxy Manager"
        case .ssh: "SSH"
        }
    }

    var brandColor: Color {
        switch self {
        case .portainer: DesignSystem.Colors.accent
        case .nginxProxyManager: DesignSystem.Colors.npm
        case .ssh: .green
        }
    }

    nonisolated var systemImage: String {
        switch self {
        case .portainer: "shippingbox.fill"
        case .nginxProxyManager: "arrow.triangle.branch"
        case .ssh: "terminal.fill"
        }
    }

    nonisolated var tabSystemImage: String {
        switch self {
        case .portainer: "shippingbox"
        case .nginxProxyManager: "arrow.triangle.branch"
        case .ssh: "terminal"
        }
    }
}
