import Foundation
import SwiftData
import Observation
import OSLog

private let hostsLogger = Logger(subsystem: "com.poole.james.pier", category: "hosts")

/// Top-level coordinator for Pier's single Komodo Core connection. It keeps one cached
/// `KomodoClient` actor so navigation does not repeatedly rebuild the connection.
///
/// Komodo makes Servers a first-class, visible concept rather than a hidden implementation
/// detail. A Komodo Core commonly manages several Servers, so `HostManager` also owns the active
/// server filter (`activeServerID`, `nil` = "All servers") and the list of servers available
/// under the configured Core, for a picker in each tab's nav title menu.
///
/// Lives on the main actor because views observe its state directly.
@MainActor
@Observable
final class HostManager {
    /// The configured Core's stable identifier. Persisted via `UserDefaults`.
    private(set) var activeHostID: UUID?

    /// The active server filter within the configured Core. `nil` means "All servers".
    var activeServerID: String?

    /// Servers available under the configured Core.
    private(set) var servers: [KomodoServer] = []

    /// Cached error from the most recent connection attempt - shown by views as needed.
    var lastError: KomodoError?
    var isPresentingHostEditor = false
    var editingHost: Host?

    private var cachedClientHostID: UUID?
    private var cachedClient: KomodoClient?
    private let activeHostKey = "com.poole.james.pier.activeHostID"
    private func activeServerKey(for hostID: UUID) -> String {
        "com.poole.james.pier.activeServerID.\(hostID.uuidString)"
    }

    init() {
        if let stored = UserDefaults.standard.string(forKey: activeHostKey),
           let uuid = UUID(uuidString: stored) {
            self.activeHostID = uuid
        }
    }

    /// Returns (or lazily creates) the client for the configured Core.
    func client(for host: Host) throws -> KomodoClient {
        if cachedClientHostID == host.id, let cachedClient {
            return cachedClient
        }
        let client = try KomodoClient(host: host, allowsInsecureTLS: host.allowsInsecureTLS)
        cachedClientHostID = host.id
        cachedClient = client
        hostsLogger.debug("Created Komodo client for host \(host.id.uuidString, privacy: .private(mask: .hash))")
        return client
    }

    /// Activates the configured Core and loads its servers so the server picker is ready.
    func setActive(_ host: Host) async {
        hostsLogger.info("Setting active host to \(host.id.uuidString, privacy: .private(mask: .hash))")
        activeHostID = host.id
        UserDefaults.standard.set(host.id.uuidString, forKey: activeHostKey)
        if let stored = UserDefaults.standard.string(forKey: activeServerKey(for: host.id)), !stored.isEmpty {
            activeServerID = stored
        } else {
            activeServerID = nil
        }
        await refreshServers(for: host)
    }

    /// Updates the active server filter (`nil` = "All servers") and persists it per-host.
    func setActiveServer(_ id: String?) {
        activeServerID = id
        guard let activeHostID else { return }
        if let id {
            UserDefaults.standard.set(id, forKey: activeServerKey(for: activeHostID))
        } else {
            UserDefaults.standard.removeObject(forKey: activeServerKey(for: activeHostID))
        }
    }

    /// Removes the cached client and credentials for the configured Core.
    func forget(_ host: Host) {
        hostsLogger.info("Forgetting host \(host.id.uuidString, privacy: .private(mask: .hash))")
        if cachedClientHostID == host.id {
            cachedClientHostID = nil
            cachedClient = nil
        }
        try? KeychainService.delete(for: host.id)
        UserDefaults.standard.removeObject(forKey: activeServerKey(for: host.id))
        if activeHostID == host.id {
            activeHostID = nil
            activeServerID = nil
            servers = []
            UserDefaults.standard.removeObject(forKey: activeHostKey)
        }
    }

    /// Stores the API key/secret for a host in the Keychain and verifies them by listing servers.
    func authenticate(host: Host, apiKey: String, apiSecret: String) async throws {
        hostsLogger.info("Authenticating host \(host.id.uuidString, privacy: .private(mask: .hash))")
        try KeychainService.store(apiKey: apiKey, for: host.id)
        try KeychainService.store(apiSecret: apiSecret, for: host.id)
        invalidateClient(for: host)
        let client = try client(for: host)
        _ = try await client.testConnection()
    }

    func invalidateClient(for host: Host) {
        hostsLogger.debug("Invalidating cached client for host \(host.id.uuidString, privacy: .private(mask: .hash))")
        guard cachedClientHostID == host.id else { return }
        cachedClientHostID = nil
        cachedClient = nil
    }

    /// Loads the server list for a host. Called when a host becomes active, and to retry after
    /// a connection failure.
    func refreshServers(for host: Host) async {
        do {
            let client = try client(for: host)
            self.servers = try await client.listServers()
            self.lastError = nil
            hostsLogger.info("Loaded \(self.servers.count) servers for host \(host.id.uuidString, privacy: .private(mask: .hash))")
        } catch {
            let komodoError = KomodoError.from(error)
            self.lastError = komodoError
            hostsLogger.error("Failed to load servers for host \(host.id.uuidString, privacy: .private(mask: .hash)): \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Convenience: client for the currently active host, if there is one.
    /// Returns nil rather than throwing because views often want to render an empty state instead.
    func resolveActiveClient(in context: ModelContext) throws -> (host: Host, client: KomodoClient)? {
        guard let activeHostID else { return nil }
        let descriptor = FetchDescriptor<Host>(predicate: #Predicate { $0.id == activeHostID })
        guard let host = try context.fetch(descriptor).first else {
            throw KomodoError.serverError(code: -1, message: "The active host could not be found.")
        }
        let client = try client(for: host)
        return (host, client)
    }

    func activeClient(in context: ModelContext) -> (host: Host, client: KomodoClient)? {
        try? resolveActiveClient(in: context)
    }
}
