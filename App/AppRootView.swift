import SwiftUI
import SwiftData

/// Top-level navigation. Uses `TabView` with `.sidebarAdaptable` so iPhone shows a tab bar while
/// iPad/Mac get a sidebar. The selection is bound to an enum-typed `AppDestination` per the
/// modern Tab API.
struct AppRootView: View {
    @Environment(HostManager.self) private var hostManager
    @Query(sort: \Host.createdAt) private var hosts: [Host]
    @State private var selection: AppDestination = .containers

    var body: some View {
        @Bindable var hostManager = hostManager

        TabView(selection: $selection) {
            Tab(AppDestination.containers.displayName, systemImage: AppDestination.containers.systemImage, value: .containers) {
                ContainersTab()
            }
            Tab(AppDestination.stacks.displayName, systemImage: AppDestination.stacks.systemImage, value: .stacks) {
                StacksTab()
            }
            Tab(AppDestination.images.displayName, systemImage: AppDestination.images.systemImage, value: .images) {
                ImagesTab()
            }
            Tab(AppDestination.stats.displayName, systemImage: AppDestination.stats.systemImage, value: .stats) {
                StatsTab()
            }
            Tab(AppDestination.settings.displayName, systemImage: AppDestination.settings.systemImage, value: .settings) {
                SettingsTab()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .task(id: hosts.map(\.id)) {
            await ensureActiveHost()
        }
        .sheet(isPresented: $hostManager.isPresentingHostEditor) {
            NavigationStack {
                HostEditorView(host: nil)
            }
        }
    }

    /// On launch, if there is no active host yet, pick the first known host and load its endpoint.
    /// If there are no hosts at all, surface the new-host sheet.
    private func ensureActiveHost() async {
        if hosts.isEmpty {
            hostManager.isPresentingHostEditor = true
            return
        }
        hostManager.isPresentingHostEditor = false
        if hostManager.activeHostID == nil, let first = hosts.first {
            await hostManager.setActive(first)
        } else if let activeID = hostManager.activeHostID,
                  let host = hosts.first(where: { $0.id == activeID }),
                  hostManager.activeEndpointID == nil {
            await hostManager.refreshActiveEndpoint(for: host)
        }
    }
}
