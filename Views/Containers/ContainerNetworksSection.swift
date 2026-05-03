import SwiftUI

/// Networks section. Each network row shows the IP address and gateway.
struct ContainerNetworksSection: View {
    let networkSettings: ContainerDetail.NetworkSettings

    var body: some View {
        if !networkSettings.networks.isEmpty {
            Section("Networks") {
                ForEach(Array(networkSettings.networks.keys).sorted(), id: \.self) { name in
                    if let info = networkSettings.networks[name] {
                        ContainerNetworkRow(name: name, info: info)
                    }
                }
            }
        }
    }
}

/// One row inside `ContainerNetworksSection`. Pulled out so the parent view body stays simple.
struct ContainerNetworkRow: View {
    let name: String
    let info: ContainerDetail.NetworkInfo

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
            if !info.ipAddress.isEmpty {
                LabeledContent("IP", value: info.ipAddress)
                    .font(.caption)
            }
            if !info.gateway.isEmpty {
                LabeledContent("Gateway", value: info.gateway)
                    .font(.caption)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
    }
}
