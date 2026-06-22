import SwiftUI
import SwiftData

/// Top-level navigation. Uses `TabView` with `.sidebarAdaptable` so iPhone shows a tab bar while
/// iPad/Mac get a sidebar. The selection is bound to an enum-typed `AppDestination` per the
/// modern Tab API.
struct AppRootView: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(NPMHostManager.self) private var npmHostManager
    @Environment(SSHSessionStore.self) private var sshSessionStore
    @Query(sort: \Host.createdAt) private var hosts: [Host]
    @Query(sort: \NPMHost.createdAt) private var npmHosts: [NPMHost]
    @Query(sort: \SSHProfile.createdAt) private var sshProfiles: [SSHProfile]
    @State private var selection: AppDestination = .containers
    @State private var isShowingSSHSession = false
    @State private var isShowingCloseSSHConfirm = false
    @State private var isInWelcomeFlow = true
    @State private var setupTarget: SetupTarget?
    @State private var didEvaluateWelcomeState = false

    var body: some View {
        Group {
            if shouldShowWelcomeScreen {
                welcomeScreen
            } else {
                tabContent
            }
        }
        .sheet(item: $setupTarget) { target in
            setupSheet(for: target)
        }
        .onAppear {
            evaluateInitialWelcomeStateIfNeeded()
        }
        .onOpenURL(perform: handleOpenURL)
    }

    private var welcomeScreen: some View {
        WelcomeFlowView(
            isInWelcomeFlow: $isInWelcomeFlow,
            setupTarget: $setupTarget,
            configuredServices: WelcomeServicesState(
                portainer: !hosts.isEmpty,
                nginxProxyManager: !npmHosts.isEmpty,
                ssh: !sshProfiles.isEmpty
            )
        )
    }

    private var tabContent: some View {
        @Bindable var hostManager = hostManager

        return TabView(selection: $selection) {
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
    }

    @ViewBuilder
    private func setupSheet(for target: SetupTarget) -> some View {
        switch target {
        case .portainer:
            NavigationStack {
                HostEditorView(host: activePortainerHost)
            }
        case .nginxProxyManager:
            NavigationStack {
                NPMHostEditorView(host: activeNPMHost)
            }
        case .ssh:
            SSHProfileEditSheet(existing: activeSSHProfile)
        }
    }

    /// On launch, if there is no active host yet, pick the first known host and load its endpoint.
    /// If there are no Portainer hosts, leave the tab-level empty states in control.
    private func ensureActiveHost() async {
        guard !shouldShowWelcomeScreen else { return }
        if hosts.isEmpty {
            hostManager.isPresentingHostEditor = false
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

    private var shouldShowWelcomeScreen: Bool {
        didEvaluateWelcomeState ? isInWelcomeFlow : !hasConfiguredAnyService
    }

    private var hasConfiguredAnyService: Bool {
        !hosts.isEmpty || !npmHosts.isEmpty || !sshProfiles.isEmpty
    }

    private func evaluateInitialWelcomeStateIfNeeded() {
        guard !didEvaluateWelcomeState else { return }

        isInWelcomeFlow = !hasConfiguredAnyService
        didEvaluateWelcomeState = true
    }

    private var activePortainerHost: Host? {
        if let activeHostID = hostManager.activeHostID,
           let activeHost = hosts.first(where: { $0.id == activeHostID }) {
            return activeHost
        }
        return hosts.first
    }

    private var activeNPMHost: NPMHost? {
        if let activeNPMHostID = npmHostManager.activeNPMHostID,
           let activeHost = npmHosts.first(where: { $0.id == activeNPMHostID }) {
            return activeHost
        }
        return npmHosts.first
    }

    private var activeSSHProfile: SSHProfile? {
        sshProfiles.first
    }

    private func handleOpenURL(_ url: URL) {
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
        isInWelcomeFlow = false
        selection = .ssh
        sshSessionStore.focusSession()
        isShowingSSHSession = true
    }
}
