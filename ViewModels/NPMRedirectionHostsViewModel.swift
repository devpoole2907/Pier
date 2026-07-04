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
        let displayName = items.first(where: { $0.id == id })?.domain_names.joined(separator: ", ") ?? "Redirection Host"
        let state: NPMActionState = enabled ? .enabling : .disabling
        actionStates[id] = state
        defer { actionStates[id] = nil }
        do {
            try await client.setRedirectionHostEnabled(id: id, enabled: enabled)
            await load()
            InAppNotificationCenter.shared.showSuccess(title: enabled ? "Redirection Host Enabled" : "Redirection Host Disabled", message: displayName)
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure(enabled ? "Enable Redirection Host" : "Disable Redirection Host", error: npmError)
        }
    }

    func delete(_ id: Int) async {
        let displayName = items.first(where: { $0.id == id })?.domain_names.joined(separator: ", ") ?? "Redirection Host"
        actionStates[id] = .deleting
        defer { actionStates[id] = nil }
        do {
            try await client.deleteRedirectionHost(id: id)
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Redirection Host Deleted", message: displayName)
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Delete Redirection Host", error: npmError)
        }
    }

    func save(create payload: NPMRedirectionHostCreate) async {
        do {
            _ = try await client.createRedirectionHost(payload)
            loadError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Redirection Host Created", message: payload.domain_names.joined(separator: ", "))
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Create Redirection Host", error: npmError)
        }
    }

    func save(update id: Int, payload: NPMRedirectionHostUpdate) async {
        do {
            _ = try await client.updateRedirectionHost(id: id, payload)
            loadError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Redirection Host Updated", message: payload.domain_names.joined(separator: ", "))
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Update Redirection Host", error: npmError)
        }
    }
}
