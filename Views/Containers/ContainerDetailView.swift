import SwiftUI

/// Container detail screen. Shows configuration sections, live stats, and provides a destructive action toolbar.
struct ContainerDetailView: View {
    @State private var viewModel: ContainerDetailViewModel
    @State private var pendingDestructiveAction: DestructiveAction?
    @State private var isShowingLogs = false
    @AppStorage("refreshIntervalSeconds") private var refreshIntervalRaw: Int = RefreshInterval.medium.rawValue

    private let hostID: UUID

    private var isShowingActionError: Binding<Bool> {
        Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } }
        )
    }

    init(client: KomodoClient, hostID: UUID, serverID: String, containerID: String, initialName: String) {
        self.hostID = hostID
        _viewModel = State(initialValue: ContainerDetailViewModel(
            client: client,
            serverID: serverID,
            containerID: containerID,
            initialName: initialName
        ))
    }

    var body: some View {
        let base = detailContent
            .navigationTitle(viewModel.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { actionsMenu }
            .navigationDestination(isPresented: $isShowingLogs) {
                ContainerLogsView(
                    client: viewModel.komodoClient,
                    serverID: viewModel.serverID,
                    containerID: viewModel.containerID
                )
            }
        let withAlerts = base
            .alert(item: $pendingDestructiveAction, content: destructiveAlert)
            .alert("Action failed", isPresented: isShowingActionError, presenting: viewModel.actionError) { _ in
                Button("OK") { viewModel.actionError = nil }
            } message: { error in
                Text(error.errorDescription ?? "Unknown error")
            }
        return withAlerts
            .task { await viewModel.load() }
            .refreshable {
                await viewModel.load()
                await viewModel.refreshStats()
            }
            .task(id: refreshIntervalRaw) {
                await viewModel.runStatsPolling(every: RefreshInterval(rawValue: refreshIntervalRaw)?.seconds)
            }
    }

    @ToolbarContentBuilder
    private var actionsMenu: some ToolbarContent {
        ToolbarItem(placement: .platformTrailing) {
            Menu("Actions", systemImage: "ellipsis.circle") {
                Button("Logs", systemImage: "doc.text") {
                    isShowingLogs = true
                }

                let isRunning = viewModel.detail?.state.running ?? false
                Divider()

                if isRunning {
                    Button("Stop", systemImage: "stop.fill") {
                        pendingDestructiveAction = .stop
                    }

                    Button("Restart", systemImage: "arrow.clockwise") {
                        pendingDestructiveAction = .restart
                    }

                    Button("Kill", systemImage: "bolt.slash.fill") {
                        pendingDestructiveAction = .kill
                    }
                } else {
                    Button("Start", systemImage: "play.fill") {
                        Task { await viewModel.start() }
                    }
                }

                Divider()

                Button("Delete", systemImage: "trash", role: .destructive) {
                    pendingDestructiveAction = .delete
                }
            }
            .disabled(viewModel.isPerformingAction)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if viewModel.detail == nil {
            if viewModel.isLoading {
                LoadingView(message: "Loading container…")
            } else if let error = viewModel.loadError {
                ErrorView(error: error, retry: {
                    Task { await viewModel.load() }
                })
            } else {
                EmptyStateView(title: "No data", systemImage: "tray")
            }
        } else if let detail = viewModel.detail {
            ContainerDetailContent(viewModel: viewModel, detail: detail, hostID: hostID)
        }
    }

    private func destructiveAlert(for action: DestructiveAction) -> Alert {
        switch action {
        case .stop:
            Alert(
                title: Text("Stop container?"),
                message: Text("This stops \(viewModel.displayName) gracefully."),
                primaryButton: .destructive(Text("Stop")) { Task { await viewModel.stop() } },
                secondaryButton: .cancel()
            )
        case .restart:
            Alert(
                title: Text("Restart container?"),
                message: Text("This restarts \(viewModel.displayName)."),
                primaryButton: .destructive(Text("Restart")) { Task { await viewModel.restart() } },
                secondaryButton: .cancel()
            )
        case .kill:
            Alert(
                title: Text("Kill container?"),
                message: Text("This sends SIGKILL to \(viewModel.displayName) immediately."),
                primaryButton: .destructive(Text("Kill")) { Task { await viewModel.kill() } },
                secondaryButton: .cancel()
            )
        case .delete:
            Alert(
                title: Text("Delete container?"),
                message: Text("This removes \(viewModel.displayName). It cannot be undone."),
                primaryButton: .destructive(Text("Delete")) { Task { await viewModel.delete() } },
                secondaryButton: .cancel()
            )
        }
    }
}

/// Action types for the destructive confirmation alert.
enum DestructiveAction: String, Identifiable {
    case stop, restart, kill, delete
    var id: String { rawValue }
}
