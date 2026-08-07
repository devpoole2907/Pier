import SwiftUI

/// Lists Komodo procedures with a Run action (swipe or context menu), guarded by a confirmation
/// dialog since running a procedure executes every stage immediately.
struct ProceduresListView: View {
    @State private var viewModel: ProceduresViewModel
    @State private var pendingRun: Procedure?
    @State private var runFeedback = false

    init(client: KomodoClient) {
        _viewModel = State(initialValue: ProceduresViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.procedures.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading procedures…")
            } else if let error = viewModel.loadError, viewModel.procedures.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.procedures.isEmpty {
                EmptyStateView(
                    title: "No procedures",
                    systemImage: "list.bullet.clipboard",
                    message: "Procedures configured in Komodo will appear here."
                )
            } else if viewModel.visibleProcedures.isEmpty {
                ContentUnavailableView.search
            } else {
                contentList
            }
        }
        .searchable(text: $viewModel.searchText, placement: .alwaysVisible, prompt: "Search procedures")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .confirmationDialog(
            "Run \(pendingRun?.name ?? "this procedure")?",
            isPresented: isPresentingRunConfirmation,
            titleVisibility: .visible
        ) {
            Button("Run") {
                confirmRun()
            }
            Button("Cancel", role: .cancel) {
                pendingRun = nil
            }
        } message: {
            Text(runConfirmationMessage)
        }
        .sensoryFeedback(.success, trigger: runFeedback)
    }

    @ViewBuilder
    private var contentList: some View {
        List {
            ForEach(viewModel.visibleProcedures) { procedure in
                ProcedureRowView(procedure: procedure, isRunning: viewModel.isRunning(procedure))
                    .swipeActions(edge: .trailing) {
                        if !viewModel.isRunning(procedure) {
                            Button("Run", systemImage: "play.fill") {
                                pendingRun = procedure
                            }
                            .tint(.blue)
                        }
                    }
                    .contextMenu {
                        if !viewModel.isRunning(procedure) {
                            Button("Run", systemImage: "play.fill") {
                                pendingRun = procedure
                            }
                        }
                    }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private var isPresentingRunConfirmation: Binding<Bool> {
        Binding(get: { pendingRun != nil }, set: { if !$0 { pendingRun = nil } })
    }

    private var runConfirmationMessage: String {
        let stages = pendingRun?.stages ?? 0
        return "This runs all \(stages) stage\(stages == 1 ? "" : "s") immediately."
    }

    private func confirmRun() {
        guard let procedure = pendingRun else { return }
        runFeedback.toggle()
        Task { await viewModel.run(procedure) }
        pendingRun = nil
    }
}
