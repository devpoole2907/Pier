import SwiftUI
import SwiftData

/// Filter values for the segment bar atop `TerminalsTab`. `.all` shows every section; the others
/// isolate a single section.
enum TerminalsFilter: Hashable {
    case all
    case ssh
    case server
    case container
    case stack
    case deployment
}

/// Pairs a Komodo terminal target with the host it belongs to, so the sheet that presents
/// `KomodoTerminalView` has everything it needs to build a connection.
private struct KomodoTerminalPresentation: Identifiable {
    let host: Host
    let target: KomodoTerminalTarget
    var id: String { target.id }
}

/// Unified "Terminals" tab: SSH hosts (existing functionality, unchanged) alongside Komodo
/// terminal targets (server/container/stack/deployment), each opening a live `KomodoTerminalView`
/// backed by `KomodoTerminalConnection`.
struct TerminalsTab: View {
    @Environment(SSHSessionStore.self) private var sshSessionStore
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SSHProfile.createdAt) private var sshProfiles: [SSHProfile]

    @State private var filter: TerminalsFilter = .all
    @State private var komodoResources = TerminalsKomodoResources()

    // SSH sheets — same machinery as the pre-Terminals-tab `SSHTab`/`SSHProfileListView`.
    @State private var isShowingSSHSession = false
    @State private var showAddSSHSheet = false
    @State private var editSSHProfile: SSHProfile?

    // Komodo terminal session + "+" menu config sheets.
    @State private var komodoTerminalPresentation: KomodoTerminalPresentation?
    @State private var komodoConfigKind: KomodoTerminalTarget.Kind?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrawlSegmentBar("Filter", selection: $filter, items: filterItems)
                list
            }
            .navigationTitle("Terminals")
            #if os(iOS)
            .toolbarTitleDisplayMode(.large)
            #endif
            .toolbar { addMenu }
            .task(id: hostManager.activeHostID) {
                await loadKomodoResources()
            }
            .refreshable {
                await loadKomodoResources()
            }
        }
        .sheet(isPresented: $isShowingSSHSession, onDismiss: {
            sshSessionStore.wantsKeyboard = false
        }) {
            NavigationStack {
                SSHSessionContainerView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showAddSSHSheet) {
            SSHProfileEditSheet(existing: nil)
        }
        .sheet(item: $editSSHProfile) { profile in
            SSHProfileEditSheet(existing: profile)
        }
        .sheet(item: $komodoTerminalPresentation) { presentation in
            KomodoTerminalView(host: presentation.host, target: presentation.target)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $komodoConfigKind) { kind in
            KomodoTerminalConfigSheet(
                kind: kind,
                servers: hostManager.servers,
                resources: komodoResources
            ) { target in
                komodoConfigKind = nil
                openKomodoTerminal(target)
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            if showsSection(.ssh) {
                SSHHostsSection(profiles: sshProfiles, openSession: openSSHSession, editTarget: $editSSHProfile)
            }

            if hasActiveKomodoClient {
                if showsSection(.server) { serverSection }
                if showsSection(.container) { containerSection }
                if showsSection(.stack) { stackSection }
                if showsSection(.deployment) { deploymentSection }
            } else if filter != .ssh {
                noKomodoHostHint
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private func showsSection(_ section: TerminalsFilter) -> Bool {
        filter == .all || filter == section
    }

    // MARK: - Komodo sections

    @ViewBuilder
    private var serverSection: some View {
        Section("Servers") {
            if hostManager.servers.isEmpty {
                Text("No servers found.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(hostManager.servers) { server in
                    Button {
                        openKomodoTerminal(KomodoTerminalTarget(
                            kind: .server,
                            resourceID: server.id,
                            name: server.name,
                            subtitle: server.state.label
                        ))
                    } label: {
                        KomodoTerminalRowView(icon: "server.rack", name: server.name, subtitle: server.state.label)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var containerSection: some View {
        Section("Containers") {
            if komodoResources.containers.isEmpty {
                Text(komodoResources.isLoading ? "Loading…" : "No containers found.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(komodoResources.containers) { container in
                    Button {
                        openKomodoTerminal(KomodoTerminalTarget(
                            kind: .container,
                            resourceID: container.id,
                            name: container.displayName,
                            subtitle: containerSubtitle(container),
                            serverID: container.serverID
                        ))
                    } label: {
                        KomodoTerminalRowView(
                            icon: "shippingbox",
                            name: container.displayName,
                            subtitle: containerSubtitle(container)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var stackSection: some View {
        Section("Stacks") {
            if komodoResources.stacks.isEmpty {
                Text(komodoResources.isLoading ? "Loading…" : "No stacks found.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(komodoResources.stacks) { stack in
                    let subtitle = "\(serverName(for: stack.serverID)) • \(stack.state.label)"
                    Button {
                        openKomodoTerminal(KomodoTerminalTarget(
                            kind: .stack,
                            resourceID: stack.id,
                            name: stack.name,
                            subtitle: subtitle,
                            serviceName: stack.services.first?.service
                        ))
                    } label: {
                        KomodoTerminalRowView(icon: "square.stack.3d.up", name: stack.name, subtitle: subtitle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var deploymentSection: some View {
        Section("Deployments") {
            if komodoResources.deployments.isEmpty {
                Text(komodoResources.isLoading ? "Loading…" : "No deployments found.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(komodoResources.deployments) { deployment in
                    let subtitle = "\(serverName(for: deployment.serverID)) • \(deployment.state.label)"
                    Button {
                        openKomodoTerminal(KomodoTerminalTarget(
                            kind: .deployment,
                            resourceID: deployment.id,
                            name: deployment.name,
                            subtitle: subtitle
                        ))
                    } label: {
                        KomodoTerminalRowView(icon: "arrow.up.forward.app", name: deployment.name, subtitle: subtitle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var noKomodoHostHint: some View {
        Section {
            Label("Connect a Komodo host to add Komodo terminals", systemImage: "server.rack")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var addMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("SSH Host", systemImage: "terminal") {
                    showAddSSHSheet = true
                }

                if hasActiveKomodoClient {
                    Section("Komodo") {
                        ForEach(KomodoTerminalTarget.Kind.allCases) { kind in
                            Button(kind.label, systemImage: kind.systemImage) {
                                komodoConfigKind = kind
                            }
                        }
                    }
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .labelStyle(.iconOnly)
        }
    }

    // MARK: - Actions

    private func openSSHSession(_ profile: SSHProfile) {
        sshSessionStore.addSession(for: profile)
        isShowingSSHSession = true
    }

    private func loadKomodoResources() async {
        guard let client = hostManager.activeClient(in: modelContext)?.client else {
            komodoResources.clear()
            return
        }
        await komodoResources.load(client: client)
    }

    /// Opens a live terminal for the given target on the active host. A no-op if there's
    /// somehow no active host — the Komodo sections/menu are only shown while one is active.
    private func openKomodoTerminal(_ target: KomodoTerminalTarget) {
        guard let host = hostManager.activeClient(in: modelContext)?.host else { return }
        komodoTerminalPresentation = KomodoTerminalPresentation(host: host, target: target)
    }

    // MARK: - Helpers

    private var hasActiveKomodoClient: Bool {
        hostManager.activeClient(in: modelContext) != nil
    }

    private func serverName(for serverID: String) -> String {
        hostManager.servers.first(where: { $0.id == serverID })?.name ?? serverID
    }

    private func containerSubtitle(_ container: Container) -> String {
        "\(serverName(for: container.serverID)) • \(container.status)"
    }

    private var filterItems: [TrawlSegmentBarItem<TerminalsFilter>] {
        [
            TrawlSegmentBarItem("All", value: .all),
            TrawlSegmentBarItem("SSH", value: .ssh),
            TrawlSegmentBarItem("Server", value: .server),
            TrawlSegmentBarItem("Container", value: .container),
            TrawlSegmentBarItem("Stack", value: .stack),
            TrawlSegmentBarItem("Deployment", value: .deployment)
        ]
    }
}
