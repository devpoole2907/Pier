import SwiftUI
import SwiftData

/// Top-level navigation. Uses `TabView` with `.sidebarAdaptable` so iPhone shows a tab bar while
/// iPad/Mac get a sidebar. The selection is bound to an enum-typed `AppDestination` per the
/// modern Tab API.
struct AppRootView: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(SSHSessionStore.self) private var sshSessionStore
    @Query(sort: \Host.createdAt) private var hosts: [Host]
    @State private var selection: AppDestination = .containers
    @State private var isShowingSSHSession = false
    @State private var isShowingCloseSSHConfirm = false

    var body: some View {
        @Bindable var hostManager = hostManager

        TabView(selection: $selection) {
            Tab(AppDestination.containers.displayName, systemImage: AppDestination.containers.systemImage, value: .containers) {
                ContainersTab()
            }
            Tab(AppDestination.proxy.displayName, systemImage: AppDestination.proxy.systemImage, value: .proxy) {
                ProxyTab()
            }
            Tab(AppDestination.stacks.displayName, systemImage: AppDestination.stacks.systemImage, value: .stacks) {
                StacksTab()
            }
            Tab(AppDestination.ssh.displayName, systemImage: AppDestination.ssh.systemImage, value: .ssh) {
                SSHTab()
            }
            Tab(AppDestination.more.displayName, systemImage: AppDestination.more.systemImage, value: .more) {
                MoreTab()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .tabViewBottomAccessory(isEnabled: sshSessionStore.hasSession) {
            SSHSessionAccessoryView(
                title: sshSessionStore.sessionTitle,
                subtitle: sshSessionStore.sessionSubtitle,
                statusText: sshSessionStore.statusText,
                statusColor: sshSessionStore.statusColor,
                openSession: { isShowingSSHSession = true },
                closeSession: {
                    isShowingCloseSSHConfirm = true
                }
            )
        }
        .alert(
            "Close SSH sessions?",
            isPresented: $isShowingCloseSSHConfirm,
        ) {
            Button("Close", role: .destructive) {
                Task {
                    await sshSessionStore.disconnect(animated: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(closeSSHConfirmationMessage)
        }
        .task(id: hosts.map(\.id)) {
            await ensureActiveHost()
        }
        .sheet(isPresented: $hostManager.isPresentingHostEditor) {
            NavigationStack {
                HostEditorView(host: hostManager.editingHost)
            }
        }
        .sshSessionSheet(isPresented: $isShowingSSHSession)
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "pier",
                  url.host?.lowercased() == "ssh-session",
                  sshSessionStore.hasSession else { return }
            if let requestedProfileID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "profile" })?
                .value,
               sshSessionStore.activeProfile?.id.uuidString != requestedProfileID {
                return
            }
            selection = .ssh
            sshSessionStore.focusSession()
            isShowingSSHSession = true
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

    private var closeSSHConfirmationMessage: String {
        if sshSessionStore.sessions.count > 1 {
            return "All \(sshSessionStore.sessions.count) terminal sessions will be disconnected."
        }
        return "\(sshSessionStore.sessionTitle) will be disconnected."
    }
}
