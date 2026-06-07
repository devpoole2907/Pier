import Foundation
import Observation

@MainActor
@Observable
final class NPMAccessListsViewModel {
    private(set) var items: [NPMAccessList] = []
    private(set) var isLoading = false
    private(set) var loadError: NPMError?
    private(set) var actionStates: [Int: NPMActionState] = [:]

    var searchText: String = ""

    private let client: NPMClient

    init(client: NPMClient) {
        self.client = client
    }

    var visibleItems: [NPMAccessList] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.name.localizedStandardContains(trimmed) }
    }

    func actionState(for id: Int) -> NPMActionState? {
        actionStates[id]
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await client.listAccessLists(expand: ["clients", "items", "owner"])
            loadError = nil
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func delete(_ id: Int) async {
        actionStates[id] = .deleting
        defer { actionStates[id] = nil }
        do {
            try await client.deleteAccessList(id: id)
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func save(create payload: NPMAccessListCreate) async {
        do {
            _ = try await client.createAccessList(payload)
            loadError = nil
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func save(update id: Int, payload: NPMAccessListUpdate) async {
        do {
            _ = try await client.updateAccessList(id: id, payload)
            loadError = nil
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }
}
