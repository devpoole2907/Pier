import SwiftUI
import SwiftData

/// Top-level navigation. Uses `TabView` with `.sidebarAdaptable` so iPhone shows a tab bar while
/// iPad/Mac get a sidebar. The selection is bound to an enum-typed `AppDestination` per the
/// modern Tab API.
struct AppRootView: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(NPMHostManager.self) private var npmHostManager
    @Environment(SSHSessionStore.self) private var sshSessionStore
    @Environment(InAppNotificationCenter.self) private var inAppNotificationCenter
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Host.createdAt) private var hosts: [Host]
    @Query(sort: \NPMHost.createdAt) private var npmHosts: [NPMHost]
    @Query(sort: \SSHProfile.createdAt) private var sshProfiles: [SSHProfile]
    @State private var selection: AppDestination = .dashboard
    @State private var isShowingSSHSession = false
    @State private var isShowingCloseSSHConfirm = false
    @State private var isInWelcomeFlow = true
    @State private var setupTarget: SetupTarget?
    @State private var didEvaluateWelcomeState = false
    #if os(iOS)
    @State private var notificationWindowPresenter = InAppNotificationWindowPresenter()
    #endif

    var body: some View {
        @Bindable var inAppNotificationCenter = inAppNotificationCenter

        return Group {
            if shouldShowWelcomeScreen {
                welcomeScreen
            } else {
                tabContent
            }
        }
        .sheet(item: $setupTarget) { target in
            setupSheet(for: target)
        }
        .sheet(isPresented: $inAppNotificationCenter.isPresentingRecentNotifications) {
            RecentNotificationsView()
                .environment(inAppNotificationCenter)
        }
        .onAppear {
            evaluateInitialWelcomeStateIfNeeded()
            #if os(iOS)
            notificationWindowPresenter.install(notificationCenter: inAppNotificationCenter)
            #endif
        }
        #if os(iOS)
        .onChange(of: scenePhase) { _, _ in
            notificationWindowPresenter.install(notificationCenter: inAppNotificationCenter)
        }
        #endif
        .onOpenURL(perform: handleOpenURL)
    }

    private var welcomeScreen: some View {
        WelcomeFlowView(
            isInWelcomeFlow: $isInWelcomeFlow,
            setupTarget: $setupTarget,
            configuredServices: WelcomeServicesState(
                komodo: !hosts.isEmpty,
                nginxProxyManager: !npmHosts.isEmpty,
                ssh: !sshProfiles.isEmpty
            )
        )
    }

    private var tabContent: some View {
        @Bindable var hostManager = hostManager

        return TabView(selection: $selection) {
            Tab(AppDestination.dashboard.displayName, systemImage: AppDestination.dashboard.systemImage, value: .dashboard) {
                NavigationStack {
                    DashboardContainer()
                        .navigationTitle("Dashboard")
                        #if os(iOS)
                        .toolbarTitleDisplayMode(.inlineLarge)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    inAppNotificationCenter.showRecentNotifications()
                                } label: {
                                    Image(systemName: inAppNotificationCenter.unreadCount > 0 ? "bell.badge" : "bell")
                                }
                            }
                        }
                }
            }
            Tab(AppDestination.stacks.displayName, systemImage: AppDestination.stacks.systemImage, value: .stacks) {
                StacksTab()
            }
            Tab(AppDestination.terminals.displayName, systemImage: AppDestination.terminals.systemImage, value: .terminals) {
                TerminalsTab()
            }
            Tab(AppDestination.proxy.displayName, systemImage: AppDestination.proxy.systemImage, value: .proxy) {
                ProxyTab()
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
        case .komodo:
            NavigationStack {
                HostEditorView(host: activeKomodoHost)
            }
        case .nginxProxyManager:
            NavigationStack {
                NPMHostEditorView(host: activeNPMHost)
            }
        case .ssh:
            SSHProfileEditSheet(existing: activeSSHProfile)
        }
    }

    /// On launch, activate Pier's configured Komodo Core and load its servers. If there is no
    /// Komodo connection, leave the tab-level empty states in control.
    private func ensureActiveHost() async {
        guard !shouldShowWelcomeScreen else { return }
        guard let host = activeKomodoHost else {
            hostManager.isPresentingHostEditor = false
            return
        }
        hostManager.isPresentingHostEditor = false
        if hostManager.activeHostID != host.id {
            await hostManager.setActive(host)
        } else if hostManager.servers.isEmpty {
            await hostManager.refreshServers(for: host)
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

    private var activeKomodoHost: Host? {
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
        selection = .terminals
        sshSessionStore.focusSession()
        isShowingSSHSession = true
    }
}
