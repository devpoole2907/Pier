import Foundation
import SwiftData
import Observation
import OSLog

private let hostsLogger = Logger(subsystem: "com.poole.james.pier", category: "hosts")

/// Top-level coordinator for hosts. Owns the active host selection and a cache of
/// `PortainerClient` actor instances keyed by host UUID, so we don't tear them down
/// every time the user navigates.
///
/// Lives on the main actor because views observe its state directly.
@MainActor
@Observable
final class HostManager {
    /// The currently selected host. Persisted via `UserDefaults`.
    private(set) var activeHostID: UUID?

    /// The Portainer endpoint within the active host. Most home setups have only one.
    private(set) var activeEndpointID: Int?

    /// Cached error from the most recent connection attempt - shown by views as needed.
    var lastError: PortainerError?
    var isPresentingHostEditor = false
    var editingHost: Host?

    private var clients: [UUID: PortainerClient] = [:]
    private let activeHostKey = "com.poole.james.pier.activeHostID"

    init() {
        if let stored = UserDefaults.standard.string(forKey: activeHostKey),
           let uuid = UUID(uuidString: stored) {
            self.activeHostID = uuid
        }
    }

    /// Returns (or lazily creates) the client for a host.
    func client(for host: Host) throws -> PortainerClient {
        if let existing = clients[host.id] {
            return existing
        }
        let client = try PortainerClient(host: host, allowsInsecureTLS: host.allowsInsecureTLS)
        clients[host.id] = client
        hostsLogger.debug("Created Portainer client for host \(host.id.uuidString, privacy: .private(mask: .hash))")
        return client
    }

    /// Selects the host as active, reading its endpoint list once to find a default endpoint.
    func setActive(_ host: Host) async {
        hostsLogger.info("Setting active host to \(host.id.uuidString, privacy: .private(mask: .hash))")
        activeHostID = host.id
        UserDefaults.standard.set(host.id.uuidString, forKey: activeHostKey)
        await refreshActiveEndpoint(for: host)
    }

    /// Removes any cached client / token for a host.
    func forget(_ host: Host) {
        hostsLogger.info("Forgetting host \(host.id.uuidString, privacy: .private(mask: .hash))")
        clients[host.id] = nil
        try? KeychainService.delete(for: host.id)
        if activeHostID == host.id {
            activeHostID = nil
            activeEndpointID = nil
            UserDefaults.standard.removeObject(forKey: activeHostKey)
        }
    }

    /// Attempts to authenticate a host with a password. Caller is expected to discard the password.
    func authenticate(host: Host, password: String) async throws {
        hostsLogger.info("Authenticating host \(host.id.uuidString, privacy: .private(mask: .hash))")
        let client = try client(for: host)
        try await client.authenticate(password: password)
    }

    func invalidateClient(for host: Host) {
        hostsLogger.debug("Invalidating cached client for host \(host.id.uuidString, privacy: .private(mask: .hash))")
        clients[host.id] = nil
    }

    /// Loads the endpoint list and picks the first running one.
    func refreshActiveEndpoint(for host: Host) async {
        do {
            let client = try client(for: host)
            let endpoints = try await client.listEndpoints()
            self.activeEndpointID = endpoints.first(where: \.isUp)?.id ?? endpoints.first?.id
            self.lastError = nil
            hostsLogger.info("Resolved active endpoint \(self.activeEndpointID ?? -1) for host \(host.id.uuidString, privacy: .private(mask: .hash))")
        } catch let error as PortainerError {
            self.lastError = error
            hostsLogger.error("Failed to resolve endpoints for host \(host.id.uuidString, privacy: .private(mask: .hash)): \(error.localizedDescription, privacy: .private)")
        } catch {
            self.lastError = .serverError(code: -1, message: error.localizedDescription)
            hostsLogger.error("Failed to resolve endpoints for host \(host.id.uuidString, privacy: .private(mask: .hash)): \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Convenience: client for the currently active host, if there is one.
    /// Returns nil rather than throwing because views often want to render an empty state instead.
    func activeClient(in context: ModelContext) -> (host: Host, client: PortainerClient, endpointID: Int)? {
        guard let activeHostID,
              let activeEndpointID else { return nil }
        let descriptor = FetchDescriptor<Host>(predicate: #Predicate { $0.id == activeHostID })
        guard let host = try? context.fetch(descriptor).first,
              let client = try? client(for: host) else { return nil }
        return (host, client, activeEndpointID)
    }
}
