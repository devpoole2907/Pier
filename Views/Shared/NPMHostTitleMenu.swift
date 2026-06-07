import SwiftUI
import SwiftData

struct NPMHostTitleMenu: ViewModifier {
    @Environment(NPMHostManager.self) private var npmHostManager
    @Query(sort: \NPMHost.createdAt) private var hosts: [NPMHost]

    func body(content: Content) -> some View {
        content
            .toolbarTitleMenu {
                if !hosts.isEmpty {
                    Section("NPM Hosts") {
                        ForEach(hosts) { host in
                            Button {
                                Task { await npmHostManager.setActive(host) }
                            } label: {
                                if host.id == npmHostManager.activeNPMHostID {
                                    Label(host.name, systemImage: "checkmark")
                                } else {
                                    Text(host.name)
                                }
                            }
                        }
                    }
                }

                Button("Add NPM Host", systemImage: "plus") {
                    npmHostManager.editingHost = nil
                    npmHostManager.isPresentingHostEditor = true
                }
            }
    }
}

extension View {
    func npmHostTitleMenu() -> some View {
        modifier(NPMHostTitleMenu())
    }
}
