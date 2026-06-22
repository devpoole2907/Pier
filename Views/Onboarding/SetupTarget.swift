import Foundation

enum SetupTarget: Identifiable {
    case portainer
    case nginxProxyManager
    case ssh

    var id: String {
        switch self {
        case .portainer: "portainer"
        case .nginxProxyManager: "nginxProxyManager"
        case .ssh: "ssh"
        }
    }
}
