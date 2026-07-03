import Foundation

enum SetupTarget: Identifiable {
    case komodo
    case nginxProxyManager
    case ssh

    var id: String {
        switch self {
        case .komodo: "komodo"
        case .nginxProxyManager: "nginxProxyManager"
        case .ssh: "ssh"
        }
    }
}
