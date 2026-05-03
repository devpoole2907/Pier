import SwiftUI

/// Header section for the container detail screen - name, status, image, dates.
struct ContainerDetailHeader: View {
    let detail: ContainerDetail
    let displayName: String

    var body: some View {
        Section {
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
}
