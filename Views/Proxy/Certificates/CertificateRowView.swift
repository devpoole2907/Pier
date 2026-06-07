import SwiftUI

struct CertificateRowView: View {
    let cert: NPMCertificate
    let actionState: NPMActionState?

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(cert.nice_name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(cert.domain_names.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let provider = cert.provider {
                        Text(provider).font(.caption2).foregroundStyle(.blue)
                    }
                    if let expires = cert.expires_on {
                        Text(expiryLabel(expires))
                            .font(.caption2)
                            .foregroundStyle(expiryColor)
                    }
                }
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            if let actionState {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.small).tint(actionState.color)
                    Text(actionState.displayName).font(.caption).fontDesign(.rounded)
                }
                .foregroundStyle(actionState.color)
                .padding(.horizontal, DesignSystem.Spacing.small)
                .padding(.vertical, DesignSystem.Spacing.tight)
                .background { Capsule().fill(actionState.color.opacity(0.15)) }
            } else if cert.isExpired {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if cert.isExpiringSoon {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
    }

    private var expiryColor: AnyShapeStyle {
        if cert.isExpired { return AnyShapeStyle(.red) }
        if cert.isExpiringSoon { return AnyShapeStyle(.orange) }
        return AnyShapeStyle(.tertiary)
    }

    private func expiryLabel(_ iso: String) -> String {
        let prefix = cert.isExpired ? "Expired" : "Expires"
        return "\(prefix): \(formatDate(iso))"
    }

    private func formatDate(_ iso: String) -> String {
        guard let date = cert.expiryDate else { return iso }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
