import SwiftUI

/// A single SSH host row: icon, display name, host/user subtitle, and a trailing badge showing
/// either the "Connected" state or the configured auth method.
///
/// Extracted from `SSHProfileListView` so the exact same row can be reused by `SSHHostsSection`,
/// which backs both the standalone SSH list and the "SSH Hosts" section of `TerminalsTab`.
struct SSHProfileRowView: View {
    let profile: SSHProfile
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.green.opacity(0.14))
                    .frame(width: 50, height: 50)
                Image(systemName: "terminal.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(profile.username)@\(profile.hostDisplay)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if isConnected {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Connected")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.green.opacity(0.9))
                } else {
                    authBadge(profile.authType)
                    if profile.knownHostFingerprint != nil {
                        HStack(spacing: 2) {
                            Image(systemName: "lock.shield.fill")
                            Text("Verified")
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green.opacity(0.9))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func authBadge(_ type: SSHAuthType) -> some View {
        let (icon, label): (String, String) = switch type {
            case .password:   ("key.fill", "Password")
            case .privateKey: ("doc.badge.gearshape.fill", "Key")
        }
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(label)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
            .background(.secondary.opacity(0.1), in: Capsule())
    }
}
