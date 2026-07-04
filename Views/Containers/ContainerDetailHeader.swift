import SwiftUI

/// Header section for the container detail screen - name, status, image, server, ports, dates.
struct ContainerDetailHeader: View {
    let detail: ContainerDetail
    let displayName: String
    let serverName: String

    var body: some View {
        Section {
            LabeledContent("Server", value: serverName)
            if let portsValue {
                LabeledContent("Port", value: portsValue)
            }
            LabeledContent("Image", value: detail.config.image)
                .lineLimit(2)
                .truncationMode(.middle)
            LabeledContent("Created") {
                Text(detail.created, format: .dateTime.day().month().year().hour().minute())
            }
            if let started = detail.state.startedAt, detail.state.running {
                LabeledContent("Started") {
                    Text(started.relativeShort)
                }
            }
            LabeledContent("Status") {
                StatusBadgeView(status: ContainerStatus(rawState: detail.state.status))
            }
            if detail.restartCount > 0 {
                LabeledContent("Restart count", value: "\(detail.restartCount)")
            }
        } header: {
            Text(displayName)
                .font(.headline)
        }
    }

    /// Published host ports, unique and comma-joined (e.g. "13378, 8080"). `nil` when nothing is
    /// published, so the row is hidden entirely rather than showing an empty value.
    private var portsValue: String? {
        let hostPorts = detail.networkSettings.publishedPorts.map(\.hostPort)
        guard !hostPorts.isEmpty else { return nil }
        return hostPorts.joined(separator: ", ")
    }
}
