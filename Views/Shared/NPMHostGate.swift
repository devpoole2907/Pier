import SwiftUI
import SwiftData

struct NPMHostGate<Content: View>: View {
    @Environment(NPMHostManager.self) private var npmHostManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NPMHost.createdAt) private var hosts: [NPMHost]

    @ViewBuilder private let content: (NPMHost, NPMClient) -> Content
    private typealias ActiveClient = (host: NPMHost, client: NPMClient)

    init(@ViewBuilder content: @escaping (NPMHost, NPMClient) -> Content) {
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
            if npmHostManager.activeNPMHostID != nil {
                connectionStateView
            } else {
                NoProxyConfiguredView()
            }
        }
    }

    @ViewBuilder
    private var connectionStateView: some View {
        if let error = npmHostManager.lastError {
            ErrorView(
                error: error,
                retry: retryConnection,
                secondaryActionTitle: editServerActionTitle,
                secondaryAction: editServerAction
            )
        } else {
            LoadingView(message: "Connecting to NPM host…")
        }
    }

    private func retryConnection() {
        guard let host = activeHost else { return }
        Task {
            await npmHostManager.verifyActiveHost(host)
        }
    }

    private func editActiveHost() {
        guard let host = activeHost else { return }
        npmHostManager.editingHost = host
        npmHostManager.isPresentingHostEditor = true
    }

    private var editServerActionTitle: String? {
        activeHost == nil ? nil : "Edit Server"
    }

    private var editServerAction: (() -> Void)? {
        guard activeHost != nil else { return nil }
        return { editActiveHost() }
    }

    private var activeHost: NPMHost? {
        guard let activeID = npmHostManager.activeNPMHostID else { return nil }
        return hosts.first(where: { $0.id == activeID })
    }

    private var activeClientResult: Result<ActiveClient, NPMError>? {
        do {
            guard let active = try npmHostManager.resolveActiveClient(in: modelContext) else { return nil }
            return .success(active)
        } catch {
            return .failure(NPMError.from(error))
        }
    }
}
