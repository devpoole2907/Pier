import SwiftUI

/// Lists the containers belonging to a given stack. Reuses `ContainerListViewModel` so we don't
/// need a new endpoint - the containers list already includes stack labels.
struct StackServicesSection: View {
    let stackName: String
    let viewModel: ContainerListViewModel

    var body: some View {
        Section("Services") {
            let services = viewModel.containers.filter { $0.stackName == stackName }
            if services.isEmpty {
                Text("No services in this stack right now.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(services) { container in
                    NavigationLink(value: ContainerNavigationValue(containerID: container.id, displayName: container.displayName)) {
                        ContainerRowView(container: container)
                    }
                }
            }
        }
    }
}
