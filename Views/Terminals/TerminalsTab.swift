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
    @Query(sort: \KomodoTerminalProfile.createdAt) private var komodoProfiles: [KomodoTerminalProfile]

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
            list
                .safeAreaInset(edge: .top, spacing: 0) {
                    TrawlSegmentBar("Filter", selection: $filter, items: filterItems)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: filter)
                .navigationTitle("Terminals")
                #if os(iOS)
                .toolbarTitleDisplayMode(.inlineLarge)
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
                addKomodoProfile(target)
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
                if showsSection(.server) { profileSection(.server) }
                if showsSection(.container) { profileSection(.container) }
                if showsSection(.stack) { profileSection(.stack) }
                if showsSection(.deployment) { profileSection(.deployment) }

                if isKomodoKindFilter, komodoProfilesForFilter.isEmpty {
                    emptyKomodoHint
                }
            } else if filter != .ssh {
                noKomodoHostHint
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .softScrollEdges()
    }

    private func showsSection(_ section: TerminalsFilter) -> Bool {
        filter == .all || filter == section
    }

    /// True only when the filter isolates a specific Komodo kind. The "tap + to add" hint is scoped
    /// to these — it must never appear under All or the SSH filter (where it's just noise below the
    /// SSH hosts).
    private var isKomodoKindFilter: Bool {
        switch filter {
        case .server, .container, .stack, .deployment: true
        case .all, .ssh: false
        }
    }

    // MARK: - Komodo sections (saved targets only)

    /// One section per kind, listing only the targets the user has explicitly added via the "+"
    /// menu for the active host. Empty kinds render nothing — the list is not a live inventory.
    @ViewBuilder
    private func profileSection(_ kind: KomodoTerminalTarget.Kind) -> some View {
        let items = profiles(for: kind)
        if !items.isEmpty {
            Section(kind.pluralLabel) {
                ForEach(items) { profile in
                    Button {
                        openKomodoTerminal(profile.target)
                    } label: {
                        KomodoTerminalRowView(
                            icon: kind.systemImage,
                            name: profile.name,
                            subtitle: profile.subtitle
                        )
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    deleteProfiles(items, at: offsets)
                }
            }
        }
    }

    private var emptyKomodoHint: some View {
        Section {
            Label("Tap + to add a server, container, stack, or deployment terminal",
                  systemImage: "plus.circle")
                .foregroundStyle(.secondary)
                .font(.footnote)
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

    /// Persists a chosen target as a saved profile pinned to the active host, so it shows in the
    /// list from now on. Silently ignores duplicates.
    private func addKomodoProfile(_ target: KomodoTerminalTarget) {
        guard let hostID = hostManager.activeHostID else { return }
        let alreadySaved = komodoProfiles.contains {
            $0.hostID == hostID && $0.kindRaw == target.kind.rawValue && $0.resourceID == target.resourceID
        }
        guard !alreadySaved else { return }
        modelContext.insert(KomodoTerminalProfile(hostID: hostID, target: target))
    }

    private func deleteProfiles(_ items: [KomodoTerminalProfile], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    // MARK: - Helpers

    private var hasActiveKomodoClient: Bool {
        hostManager.activeClient(in: modelContext) != nil
    }

    /// Saved Komodo terminal profiles for the active host only — a resource id is only meaningful
    /// on the Core that owns it.
    private var activeHostProfiles: [KomodoTerminalProfile] {
        guard let hostID = hostManager.activeHostID else { return [] }
        return komodoProfiles.filter { $0.hostID == hostID }
    }

    private func profiles(for kind: KomodoTerminalTarget.Kind) -> [KomodoTerminalProfile] {
        activeHostProfiles.filter { $0.kind == kind }
    }

    /// Saved profiles that would be shown under the current filter — used to decide whether to
    /// show the "tap + to add" hint instead of a blank space.
    private var komodoProfilesForFilter: [KomodoTerminalProfile] {
        activeHostProfiles.filter { profile in
            switch filter {
            case .all: return true
            case .server: return profile.kind == .server
            case .container: return profile.kind == .container
            case .stack: return profile.kind == .stack
            case .deployment: return profile.kind == .deployment
            case .ssh: return false
            }
        }
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
