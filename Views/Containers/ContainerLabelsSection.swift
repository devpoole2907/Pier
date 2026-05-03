import SwiftUI

/// Labels section. Disclosure group so the often-long list doesn't dominate the screen.
struct ContainerLabelsSection: View {
    let labels: [String: String]

    var body: some View {
        if !labels.isEmpty {
            Section {
                DisclosureGroup("Labels (\(labels.count))") {
                    ForEach(Array(labels.keys).sorted(), id: \.self) { key in
                        if let value = labels[key] {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key)
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                    .fontWeight(.medium)
                                Text(value)
                                    .font(.caption2)
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}
