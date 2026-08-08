import SwiftUI
import SwiftData

/// Resolves the active Komodo host/client pair and renders consistent empty, loading, and error
/// states while the connection is being established. Server-level scoping (Komodo's first-class
/// Servers concept) is read separately by views from `hostManager.activeServerID` /
/// `hostManager.servers` - there is no per-endpoint integer to thread through here anymore.
struct ActiveHostGate<Content: View>: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Host.createdAt) private var hosts: [Host]

    @ViewBuilder private let content: (Host, KomodoClient) -> Content
    private typealias ActiveClient = (host: Host, client: KomodoClient)

    init(@ViewBuilder content: @escaping (Host, KomodoClient) -> Content) {
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        switch activeClientResult {
        case .success(let active):
            content(active.host, active.client)
        case .failure(let error):
            ErrorView(
                error: error,
                retry: retryConnection,
                secondaryActionTitle: editServerActionTitle,
                secondaryAction: editServerAction
            )
        case nil:
            if hostManager.activeHostID != nil {
                connectionStateView
            } else {
                NoHostConfiguredView()
            }
        }
    }

    @ViewBuilder
    private var connectionStateView: some View {
        if let error = hostManager.lastError {
            ErrorView(
                error: error,
                retry: retryConnection,
                secondaryActionTitle: editServerActionTitle,
                secondaryAction: editServerAction
            )
        } else {
            LoadingView(message: "Connecting to host…")
        }
    }

    private func retryConnection() {
        guard let host = activeHost else { return }
        Task {
            await hostManager.refreshServers(for: host)
        }
    }

    private func editActiveHost() {
        guard let host = activeHost else { return }
        hostManager.editingHost = host
        hostManager.isPresentingHostEditor = true
    }

    private var editServerActionTitle: String? {
        activeHost == nil ? nil : "Edit Komodo Connection"
    }

    private var editServerAction: (() -> Void)? {
        guard activeHost != nil else { return nil }
        return { editActiveHost() }
    }

    private var activeHost: Host? {
        guard let activeHostID = hostManager.activeHostID else { return nil }
        return hosts.first(where: { $0.id == activeHostID })
    }

    private var activeClientResult: Result<ActiveClient, KomodoError>? {
        do {
            guard let active = try hostManager.resolveActiveClient(in: modelContext) else { return nil }
            return .success(active)
        } catch {
            return .failure(KomodoError.from(error))
        }
    }
}
