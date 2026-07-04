import Foundation
import Observation

@MainActor
@Observable
final class NPMDeadHostsViewModel {
    private(set) var items: [NPMDeadHost] = []
    private(set) var isLoading = false
    private(set) var loadError: NPMError?
    private(set) var actionStates: [Int: NPMActionState] = [:]

    var searchText: String = ""

    private let client: NPMClient

    init(client: NPMClient) {
        self.client = client
    }

    var visibleItems: [NPMDeadHost] {
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
            items = try await client.listDeadHosts(expand: ["owner"])
            loadError = nil
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func setEnabled(_ id: Int, enabled: Bool) async {
        let displayName = items.first(where: { $0.id == id })?.domain_names.joined(separator: ", ") ?? "404 Host"
        let state: NPMActionState = enabled ? .enabling : .disabling
        actionStates[id] = state
        defer { actionStates[id] = nil }
        do {
            try await client.setDeadHostEnabled(id: id, enabled: enabled)
            await load()
            InAppNotificationCenter.shared.showSuccess(title: enabled ? "404 Host Enabled" : "404 Host Disabled", message: displayName)
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure(enabled ? "Enable 404 Host" : "Disable 404 Host", error: npmError)
        }
    }

    func delete(_ id: Int) async {
        let displayName = items.first(where: { $0.id == id })?.domain_names.joined(separator: ", ") ?? "404 Host"
        actionStates[id] = .deleting
        defer { actionStates[id] = nil }
        do {
            try await client.deleteDeadHost(id: id)
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "404 Host Deleted", message: displayName)
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Delete 404 Host", error: npmError)
        }
    }

    func save(create payload: NPMDeadHostCreate) async {
        do {
            _ = try await client.createDeadHost(payload)
            loadError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "404 Host Created", message: payload.domain_names.joined(separator: ", "))
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Create 404 Host", error: npmError)
        }
    }

    func save(update id: Int, payload: NPMDeadHostUpdate) async {
        do {
            _ = try await client.updateDeadHost(id: id, payload)
            loadError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "404 Host Updated", message: payload.domain_names.joined(separator: ", "))
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Update 404 Host", error: npmError)
        }
    }
}
