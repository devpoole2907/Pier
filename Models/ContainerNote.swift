import Foundation
import SwiftData

/// A user-authored description/note attached to a container. Docker/Komodo containers have no
/// native description field (only Komodo *deployments* and *variables* do, and a container in the
/// list isn't guaranteed to be a Komodo-managed deployment), so this is stored locally and keyed by
/// host + container id. Always available regardless of how the container was created.
@Model
final class ContainerNote {
    #Index<ContainerNote>([\.containerID])
    var hostID: UUID
    var containerID: String
    var text: String
    var updatedAt: Date

    init(hostID: UUID, containerID: String, text: String) {
        self.hostID = hostID
        self.containerID = containerID
        self.text = text
        self.updatedAt = .now
    }
}
