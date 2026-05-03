import SwiftUI

/// Environment variables section. Hidden when no env vars are present.
struct ContainerEnvironmentSection: View {
    let environment: [EnvVar]

    var body: some View {
        if !environment.isEmpty {
            Section("Environment") {
                ForEach(environment) { variable in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                        Text(variable.key)
                            .font(.subheadline)
                            .fontDesign(.monospaced)
                            .fontWeight(.medium)
                        Text(variable.value)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, DesignSystem.Spacing.tight)
                }
            }
        }
    }
}
