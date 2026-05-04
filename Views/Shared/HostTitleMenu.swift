import SwiftUI
import SwiftData

struct HostTitleMenu: ViewModifier {
    @Environment(HostManager.self) private var hostManager
    @Query(sort: \Host.createdAt) private var hosts: [Host]

    func body(content: Content) -> some View {
        content
            .toolbarTitleMenu {
                if !hosts.isEmpty {
                    Section("Hosts") {
                        ForEach(hosts) { host in
                            Button {
                                Task { await hostManager.setActive(host) }
                            } label: {
                                if host.id == hostManager.activeHostID {
                                    Label(host.name, systemImage: "checkmark")
                                } else {
                                    Text(host.name)
                                }
                            }
                        }
                    }
                }

                Button("Add Host", systemImage: "plus") {
                    hostManager.editingHost = nil
                    hostManager.isPresentingHostEditor = true
                }
            }
    }
}

extension View {
    func hostTitleMenu() -> some View {
        modifier(HostTitleMenu())
    }
}
