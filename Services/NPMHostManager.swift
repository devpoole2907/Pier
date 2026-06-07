import Foundation
import SwiftData
import Observation
import OSLog

private let npmHostsLogger = Logger(subsystem: "com.poole.james.pier", category: "npm.hosts")

@MainActor
@Observable
final class NPMHostManager {
    private(set) var activeNPMHostID: UUID?
    var lastError: NPMError?
    var isPresentingHostEditor = false
    var editingHost: NPMHost?

    private var clients: [UUID: NPMClient] = [:]
    private let activeHostKey = "com.poole.james.pier.npm.activeHostID"

    init() {
        if let stored = UserDefaults.standard.string(forKey: activeHostKey),
           let uuid = UUID(uuidString: stored) {
            self.activeNPMHostID = uuid
        }
    }

    func client(for host: NPMHost) throws -> NPMClient {
        if let existing = clients[host.id] {
            return existing
        }
        let client = try NPMClient(host: host, allowsInsecureTLS: host.allowsInsecureTLS)
        clients[host.id] = client
        npmHostsLogger.debug("Created NPM client for host \(host.id.uuidString, privacy: .private(mask: .hash))")
        return client
    }

    func setActive(_ host: NPMHost) async {
        npmHostsLogger.info("Setting active NPM host to \(host.id.uuidString, privacy: .private(mask: .hash))")
        activeNPMHostID = host.id
        UserDefaults.standard.set(host.id.uuidString, forKey: activeHostKey)
        await verifyActiveHost(host)
    }

    func forget(_ host: NPMHost) {
        npmHostsLogger.info("Forgetting NPM host \(host.id.uuidString, privacy: .private(mask: .hash))")
        clients[host.id] = nil
        try? KeychainService.deleteNPMCredentials(for: host.id)
        if activeNPMHostID == host.id {
            activeNPMHostID = nil
            UserDefaults.standard.removeObject(forKey: activeHostKey)
        }
    }

    func authenticate(host: NPMHost, secret: String) async throws {
        npmHostsLogger.info("Authenticating NPM host \(host.id.uuidString, privacy: .private(mask: .hash))")
        let client = try self.client(for: host)
        try await client.authenticate(secret: secret)
    }

    func invalidateClient(for host: NPMHost) {
        npmHostsLogger.debug("Invalidating cached NPM client for host \(host.id.uuidString, privacy: .private(mask: .hash))")
        clients[host.id] = nil
    }

    /// Verify the active host is reachable by pinging it.
    func verifyActiveHost(_ host: NPMHost) async {
        do {
            let client = try self.client(for: host)
            _ = try await client.ping()
            self.lastError = nil
            npmHostsLogger.info("Verified NPM host \(host.id.uuidString, privacy: .private(mask: .hash))")
        } catch {
            let npmError = NPMError.from(error)
            self.lastError = npmError
            npmHostsLogger.error("Failed to verify NPM host \(host.id.uuidString, privacy: .private(mask: .hash)): \(error.localizedDescription, privacy: .private)")
        }
    }

    func resolveActiveClient(in context: ModelContext) throws -> (host: NPMHost, client: NPMClient)? {
        guard let activeNPMHostID else { return nil }
        let descriptor = FetchDescriptor<NPMHost>(predicate: #Predicate { $0.id == activeNPMHostID })
        guard let host = try context.fetch(descriptor).first else {
            throw NPMError.serverError(code: -1, message: "The active NPM host could not be found.")
        }
        let client = try self.client(for: host)
        return (host, client)
    }

    func activeClient(in context: ModelContext) -> (host: NPMHost, client: NPMClient)? {
        try? resolveActiveClient(in: context)
    }
}
