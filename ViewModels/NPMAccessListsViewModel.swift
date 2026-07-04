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
        let displayName = items.first(where: { $0.id == id })?.name ?? "Access List"
        actionStates[id] = .deleting
        defer { actionStates[id] = nil }
        do {
            try await client.deleteAccessList(id: id)
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Access List Deleted", message: displayName)
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Delete Access List", error: npmError)
        }
    }

    func save(create payload: NPMAccessListCreate) async {
        do {
            _ = try await client.createAccessList(payload)
            loadError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Access List Created", message: payload.name)
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Create Access List", error: npmError)
        }
    }

    func save(update id: Int, payload: NPMAccessListUpdate) async {
        do {
            _ = try await client.updateAccessList(id: id, payload)
            loadError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Access List Updated", message: payload.name)
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Update Access List", error: npmError)
        }
    }
}
