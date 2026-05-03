import SwiftUI

/// Bottom action toolbar pinned to the safe area inset of the container detail view.
/// Buttons are rendered with text labels (not icon-only) so VoiceOver reads them clearly.
struct ContainerActionToolbar: View {
    let viewModel: ContainerDetailViewModel
    @Binding var pendingAction: DestructiveAction?

    var body: some View {
        let detail = viewModel.detail
        let isRunning = detail?.state.running ?? false

        HStack(spacing: DesignSystem.Spacing.small) {
            if isRunning {
                Button("Stop", systemImage: "stop.fill") {
                    pendingAction = .stop
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("Restart", systemImage: "arrow.clockwise") {
                    pendingAction = .restart
                }
                .buttonStyle(.bordered)

                Button("Kill", systemImage: "bolt.slash.fill") {
                    pendingAction = .kill
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button("Start", systemImage: "play.fill") {
                    Task { await viewModel.start() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Delete", systemImage: "trash", role: .destructive) {
                    pendingAction = .delete
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.regular)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, DesignSystem.Spacing.large)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(.bar)
        .disabled(viewModel.isPerformingAction)
    }
}
