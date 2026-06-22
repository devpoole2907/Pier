import Foundation

struct WelcomeServicesState {
    var portainer: Bool
    var nginxProxyManager: Bool
    var ssh: Bool

    var hasAny: Bool {
        portainer || nginxProxyManager || ssh
    }
}
