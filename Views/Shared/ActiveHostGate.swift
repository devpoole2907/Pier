import SwiftUI
import SwiftData

/// Resolves the active Portainer host/client pair and renders consistent empty, loading, and error
/// states while the host endpoint is being established.
struct ActiveHostGate<Content: View>: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Host.createdAt) private var hosts: [Host]

    @ViewBuilder private let content: (Host, PortainerClient, Int) -> Content
    private typealias ActiveClient = (host: Host, client: PortainerClient, endpointID: Int)

    init(@ViewBuilder content: @escaping (Host, PortainerClient, Int) -> Content) {
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        switch activeClientResult {
        case .success(let active):
            content(active.host, active.client, active.endpointID)
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
            await hostManager.refreshActiveEndpoint(for: host)
        }
    }

    private func editActiveHost() {
        guard let host = activeHost else { return }
        hostManager.editingHost = host
        hostManager.isPresentingHostEditor = true
    }

    private var editServerActionTitle: String? {
        activeHost == nil ? nil : "Edit Server"
    }

    private var editServerAction: (() -> Void)? {
        guard activeHost != nil else { return nil }
        return { editActiveHost() }
    }

    private var activeHost: Host? {
        guard let activeHostID = hostManager.activeHostID else { return nil }
        return hosts.first(where: { $0.id == activeHostID })
    }

    private var activeClientResult: Result<ActiveClient, PortainerError>? {
        do {
            guard let active = try hostManager.resolveActiveClient(in: modelContext) else { return nil }
            return .success(active)
        } catch {
            return .failure(PortainerError.from(error))
        }
    }
}
