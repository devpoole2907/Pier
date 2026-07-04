import Foundation
import SwiftData

/// A Komodo terminal target the user has explicitly added (via the "+" menu) and pinned to the
/// Terminals tab. Mirrors how `SSHProfile` persists SSH hosts: the Terminals list shows only these
/// saved profiles, never the full live resource inventory. Tapping one opens a live terminal by
/// materialising it back into a `KomodoTerminalTarget`.
@Model
final class KomodoTerminalProfile {
    @Attribute(.unique) var id: UUID

    /// The Komodo host (Core) this target belongs to, so the Terminals list can scope profiles to
    /// the active host — a resource id only means something on the Core that owns it.
    var hostID: UUID

    /// Raw value of `KomodoTerminalTarget.Kind`.
    var kindRaw: String
    var resourceID: String
    var name: String
    var subtitle: String
    var serverID: String?
    var serviceName: String?
    /// Raw value of `KomodoTerminalTarget.Mode`. Defaulted so existing SwiftData rows
    /// lightweight-migrate cleanly.
    var modeRaw: String = KomodoTerminalTarget.Mode.exec.rawValue
    var terminalName: String?
    var createdAt: Date

    init(hostID: UUID, target: KomodoTerminalTarget) {
        self.id = UUID()
        self.hostID = hostID
        self.kindRaw = target.kind.rawValue
        self.resourceID = target.resourceID
        self.name = target.name
        self.subtitle = target.subtitle
        self.serverID = target.serverID
        self.serviceName = target.serviceName
        self.modeRaw = target.mode.rawValue
        self.terminalName = target.terminalName
        self.createdAt = .now
    }

    var kind: KomodoTerminalTarget.Kind {
        KomodoTerminalTarget.Kind(rawValue: kindRaw) ?? .server
    }

    /// Rebuilds the addressable target this profile stands for, to hand to `KomodoTerminalView`.
    var target: KomodoTerminalTarget {
        KomodoTerminalTarget(
            kind: kind,
            resourceID: resourceID,
            name: name,
            subtitle: subtitle,
            serverID: serverID,
            serviceName: serviceName,
            mode: KomodoTerminalTarget.Mode(rawValue: modeRaw) ?? .exec,
            terminalName: terminalName
        )
    }
}
