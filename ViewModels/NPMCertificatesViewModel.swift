import Foundation
import Observation

@MainActor
@Observable
final class NPMCertificatesViewModel {
    private(set) var items: [NPMCertificate] = []
    private(set) var isLoading = false
    private(set) var loadError: NPMError?
    private(set) var actionStates: [Int: NPMActionState] = [:]
    /// The certificate produced by the most recent successful `save(create:)`, so
    /// callers (e.g. the proxy-host editor) can auto-select a freshly requested cert.
    private(set) var lastCreated: NPMCertificate?

    var searchText: String = ""

    private let client: NPMClient

    init(client: NPMClient) {
        self.client = client
    }

    var visibleItems: [NPMCertificate] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            item.nice_name.localizedStandardContains(trimmed)
                || item.domain_names.contains(where: { $0.localizedStandardContains(trimmed) })
        }
    }

    func actionState(for id: Int) -> NPMActionState? {
        actionStates[id]
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await client.listCertificates(expand: ["owner"])
            loadError = nil
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func delete(_ id: Int) async {
        actionStates[id] = .deleting
        defer { actionStates[id] = nil }
        do {
            try await client.deleteCertificate(id: id)
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func save(create payload: NPMCertificateCreate) async {
        do {
            lastCreated = try await client.createCertificate(payload)
            loadError = nil
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func renew(_ id: Int) async {
        actionStates[id] = .renewing
        defer { actionStates[id] = nil }
        do {
            _ = try await client.renewCertificate(id: id)
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }
}
