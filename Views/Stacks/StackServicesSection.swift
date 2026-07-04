import SwiftUI

/// Lists a stack's services. The service list comes from `stack.services` (Komodo's `ListStacks`
/// `info.services`) rather than filtering the container list — Komodo's container list carries no
/// compose-project label (`Container.stackName` is always nil), so filtering by it matched nothing.
/// Each service is matched back to a live container when possible so the row can drill into
/// container detail; unmatched services still render as a static summary row.
struct StackServicesSection: View {
    let stack: Stack
    let viewModel: ContainerListViewModel

    var body: some View {
        Section("Services") {
            if stack.services.isEmpty {
                Text("No services in this stack.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stack.services) { service in
                    if let container = matchingContainer(for: service) {
                        NavigationLink(value: ContainerNavigationValue(
                            containerID: container.id,
                            serverID: container.serverID,
                            displayName: container.displayName
                        )) {
                            ContainerRowView(container: container, actionState: viewModel.actionState(for: container))
                        }
                        .disabled(viewModel.isActionInProgress(for: container))
                    } else {
                        serviceRow(service)
                    }
                }
            }
        }
    }

    /// Static row for a service with no resolvable running container (stopped, or name didn't match).
    private func serviceRow(_ service: StackServiceInfo) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
            HStack {
                Text(service.service)
                    .font(.body)
                    .fontWeight(.medium)
                if service.updateAvailable {
                    Text("Update")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            if !service.image.isEmpty {
                Text(service.image)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    /// Best-effort match of a compose service to its running container. Docker names compose
    /// containers `<project>-<service>-N` / `<project>_<service>_N`, so a name token equal to the
    /// service name on the same server is a strong signal; when several match, prefer the one whose
    /// name also contains the stack name.
    private func matchingContainer(for service: StackServiceInfo) -> Container? {
        let serviceName = service.service.lowercased()
        let candidates = viewModel.containers.filter { container in
            guard container.serverID == stack.serverID else { return false }
            let tokens = container.displayName.lowercased().split { $0 == "-" || $0 == "_" }.map(String.init)
            return tokens.contains(serviceName)
        }
        return candidates.first { $0.displayName.localizedCaseInsensitiveContains(stack.name) } ?? candidates.first
    }
}
