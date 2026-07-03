import SwiftUI

/// Title-menu server scope picker. Komodo Cores manage multiple Servers, so the Docker resource
/// lists (containers, images, stacks) are scoped by an active server — or "All servers" when the
/// scope is `nil`. This mirrors `HostTitleMenu` but selects the server within the active host.
///
/// Apply *after* `hostTitleMenu()` so both sections share the navigation title menu.
struct ServerScopeMenu: ViewModifier {
    @Environment(HostManager.self) private var hostManager

    func body(content: Content) -> some View {
        content.toolbarTitleMenu {
            if !hostManager.servers.isEmpty {
                Section("Server") {
                    Button {
                        hostManager.setActiveServer(nil)
                    } label: {
                        if hostManager.activeServerID == nil {
                            Label("All servers", systemImage: "checkmark")
                        } else {
                            Text("All servers")
                        }
                    }

                    ForEach(hostManager.servers) { server in
                        Button {
                            hostManager.setActiveServer(server.id)
                        } label: {
                            if server.id == hostManager.activeServerID {
                                Label(server.name, systemImage: "checkmark")
                            } else {
                                Text(server.name)
                            }
                        }
                    }
                }
            }
        }
    }
}

extension View {
    /// Adds a "Server" section to the navigation title menu for scoping Docker resource lists.
    func serverScopeMenu() -> some View {
        modifier(ServerScopeMenu())
    }

    /// A stable identity for resource views that must rebuild when either the active host or the
    /// active server scope changes. Use as `.id(hostManager.scopeIdentity(for: host))`.
    func scopedID(host: Host, serverID: String?) -> some View {
        id("\(host.id.uuidString)-\(serverID ?? "all")")
    }
}
