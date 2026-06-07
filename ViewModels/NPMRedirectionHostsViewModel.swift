import Foundation
import Observation

@MainActor
@Observable
final class NPMRedirectionHostsViewModel {
    private(set) var items: [NPMRedirectionHost] = []
    private(set) var isLoading = false
    private(set) var loadError: NPMError?
    private(set) var actionStates: [Int: NPMActionState] = [:]

    var searchText: String = ""

    private let client: NPMClient

    init(client: NPMClient) {
        self.client = client
    }

    var visibleItems: [NPMRedirectionHost] {
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
            items = try await client.listRedirectionHosts(expand: ["owner"])
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
            try await client.setRedirectionHostEnabled(id: id, enabled: enabled)
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func delete(_ id: Int) async {
        actionStates[id] = .deleting
        defer { actionStates[id] = nil }
        do {
            try await client.deleteRedirectionHost(id: id)
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func save(create payload: NPMRedirectionHostCreate) async {
        do {
            _ = try await client.createRedirectionHost(payload)
            loadError = nil
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func save(update id: Int, payload: NPMRedirectionHostUpdate) async {
        do {
            _ = try await client.updateRedirectionHost(id: id, payload)
            loadError = nil
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }
}
