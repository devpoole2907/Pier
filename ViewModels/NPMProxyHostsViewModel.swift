import Foundation
import Observation

@MainActor
@Observable
final class NPMProxyHostsViewModel {
    private(set) var items: [NPMProxyHost] = []
    private(set) var isLoading = false
    private(set) var loadError: NPMError?
    private(set) var actionStates: [Int: NPMActionState] = [:]

    var searchText: String = ""

    private let client: NPMClient

    init(client: NPMClient) {
        self.client = client
    }

    var visibleItems: [NPMProxyHost] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            item.domain_names.contains(where: { $0.localizedStandardContains(trimmed) })
        }
    }

    func actionState(for id: Int) -> NPMActionState? {
        actionStates[id]
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await client.listProxyHosts(expand: ["certificate", "access_list", "owner"])
            loadError = nil
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func setEnabled(_ id: Int, enabled: Bool) async {
        let state: NPMActionState = enabled ? .enabling : .disabling
        actionStates[id] = state
        defer { actionStates[id] = nil }
        do {
            try await client.setProxyHostEnabled(id: id, enabled: enabled)
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func delete(_ id: Int) async {
        actionStates[id] = .deleting
        defer { actionStates[id] = nil }
        do {
            try await client.deleteProxyHost(id: id)
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func save(create payload: NPMProxyHostCreate) async {
        do {
            _ = try await client.createProxyHost(payload)
            loadError = nil
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func save(update id: Int, payload: NPMProxyHostUpdate) async {
        do {
            _ = try await client.updateProxyHost(id: id, payload)
            loadError = nil
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    /// Builds a certificates view model sharing this host's client, so the proxy-host
    /// editor can request a new Let's Encrypt cert inline without re-resolving the host.
    func makeCertificatesViewModel() -> NPMCertificatesViewModel {
        NPMCertificatesViewModel(client: client)
    }

    func fetchCertificates() async -> [NPMCertificate] {
        do {
            return try await client.listCertificates()
        } catch {
            return []
        }
    }

    func fetchAccessLists() async -> [NPMAccessList] {
        do {
            return try await client.listAccessLists()
        } catch {
            return []
        }
    }
}
