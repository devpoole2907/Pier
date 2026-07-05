import SwiftUI

/// Stack detail. Shows summary, services in the stack, and a YAML editor for the compose file.
struct StackDetailView: View {
    let stack: Stack
    @State private var viewModel: StacksViewModel
    @State private var isShowingEditor = false
    @State private var pendingDelete = false
    @State private var pendingStop = false

    @State private var containerListVM: ContainerListViewModel

    init(stack: Stack, client: KomodoClient) {
        self.stack = stack
        _viewModel = State(initialValue: StacksViewModel(client: client))
        _containerListVM = State(initialValue: ContainerListViewModel(client: client, serverID: stack.serverID))
    }

    var body: some View {
        List {
            Section("Stack") {
                LabeledContent("Status") {
                    Text(stack.state.label)
                        .foregroundStyle(stack.state.color)
                }
                if !stack.statusText.isEmpty {
                    LabeledContent("Detail") {
                        Text(stack.statusText)
                            .foregroundStyle(.secondary)
                    }
                }
                if stack.updateAvailable {
                    LabeledContent("Update") {
                        Text("Available")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Updates") {
                updateToggle(
                    title: "Poll for Updates",
                    subtitle: "Check for updates to the image during Global Auto Update.",
                    systemImage: "arrow.triangle.2.circlepath",
                    isOn: policyBinding(\.pollForUpdates) { current, value in
                        StackUpdatePolicy(
                            pollForUpdates: value,
                            autoUpdate: current.autoUpdate,
                            autoUpdateAllServices: current.autoUpdateAllServices
                        )
                    }
                )

                updateToggle(
                    title: "Auto Update",
                    subtitle: "Trigger a redeploy if a newer image is found.",
                    systemImage: "bolt.badge.automatic",
                    isOn: policyBinding(\.autoUpdate) { current, value in
                        StackUpdatePolicy(
                            pollForUpdates: value ? true : current.pollForUpdates,
                            autoUpdate: value,
                            autoUpdateAllServices: current.autoUpdateAllServices
                        )
                    }
                )

                updateToggle(
                    title: "Full Stack Auto Update",
                    subtitle: "Always redeploy full stack instead of just specific services with update.",
                    systemImage: "square.stack.3d.up.fill",
                    isOn: policyBinding(\.autoUpdateAllServices) { current, value in
                        StackUpdatePolicy(
                            pollForUpdates: current.pollForUpdates,
                            autoUpdate: current.autoUpdate,
                            autoUpdateAllServices: value
                        )
                    }
                )
                .disabled(!currentUpdatePolicy.autoUpdate)
            }

            StackServicesSection(stack: stack, viewModel: containerListVM)

            Section("Compose file") {
                Button("View / edit YAML", systemImage: "doc.text") {
                    Task {
                        await viewModel.loadFile(for: stack)
                        isShowingEditor = true
                    }
                }
            }
        }
        .navigationTitle(stack.name)
        .navigationSubtitle(fileSubtitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .task {
            async let containers: Void = containerListVM.load()
            async let detail: Void = viewModel.loadDetail(for: stack)
            _ = await (containers, detail)
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                StackEditorView(
                    initialContent: viewModel.file?.contents ?? "",
                    filePath: viewModel.file?.path ?? "",
                    stackName: stack.name
                ) { newContents in
                    await viewModel.saveFile(
                        stackID: stack.id,
                        path: viewModel.file?.path ?? "",
                        contents: newContents
                    )
                }
            }
        }
        .alert("Delete stack?", isPresented: $pendingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await viewModel.destroy([stack]) }
            }
        } message: {
            Text("This removes the stack and its containers. This action cannot be undone.")
        }
        .alert("Stop stack?", isPresented: $pendingStop) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                Task { await viewModel.stop(stack) }
            }
        } message: {
            Text("This stops \(stack.name) and all its services.")
        }
    }

    /// Compose file path (or name) for the nav subtitle, once loaded. Falls back to the server
    /// name so the subtitle isn't empty before the file resolves.
    private var fileSubtitle: String {
        if let path = viewModel.file?.path, !path.isEmpty {
            return path
        }
        return ""
    }

    private var currentUpdatePolicy: StackUpdatePolicy {
        viewModel.detail?.updatePolicy ?? stack.updatePolicy
    }

    private func policyBinding(
        _ keyPath: KeyPath<StackUpdatePolicy, Bool>,
        update: @escaping (StackUpdatePolicy, Bool) -> StackUpdatePolicy
    ) -> Binding<Bool> {
        Binding(
            get: { currentUpdatePolicy[keyPath: keyPath] },
            set: { newValue in
                let nextPolicy = update(currentUpdatePolicy, newValue)
                Task { await viewModel.updatePolicy(nextPolicy, for: stack) }
            }
        )
    }

    private func updateToggle(
        title: String,
        subtitle: String,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Label {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
        .disabled(viewModel.isLoadingFile)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .platformTrailing) {
            Menu("Actions", systemImage: "ellipsis.circle") {
                Button("Pull", systemImage: "arrow.down.circle") {
                    Task { await viewModel.pull(stack) }
                }
                if stack.isActive {
                    Button("Deploy", systemImage: "arrow.triangle.pull") {
                        Task { await viewModel.deployIfChanged(stack) }
                    }
                    Button("Pull & Deploy", systemImage: "arrow.trianglehead.clockwise") {
                        Task {
                            await viewModel.pull(stack)
                            await viewModel.deploy(stack)
                        }
                    }
                }

                if stack.isActive {
                    Button("Stop stack", systemImage: "stop.fill") {
                        pendingStop = true
                    }
                } else {
                    Button("Start stack", systemImage: "play.fill") {
                        Task { await viewModel.start(stack) }
                    }
                }
                Button("Delete stack", systemImage: "trash", role: .destructive) {
                    pendingDelete = true
                }
            }
        }
    }

}
