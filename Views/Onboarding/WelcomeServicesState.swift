import Foundation

struct WelcomeServicesState {
    var komodo: Bool
    var nginxProxyManager: Bool
    var ssh: Bool

    var hasAny: Bool {
        komodo || nginxProxyManager || ssh
    }
}
