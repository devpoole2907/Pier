import Foundation
import Observation

@MainActor
@Observable
final class NPMStreamsViewModel {
    private(set) var items: [NPMStream] = []
    private(set) var isLoading = false
    private(set) var loadError: NPMError?
    private(set) var actionStates: [Int: NPMActionState] = [:]

    var searchText: String = ""

    private let client: NPMClient

    init(client: NPMClient) {
        self.client = client
    }

    var visibleItems: [NPMStream] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            String(item.incoming_port).contains(trimmed)
                || item.forwarding_host.localizedStandardContains(trimmed)
        }
    }

    func actionState(for id: Int) -> NPMActionState? {
        actionStates[id]
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await client.listStreams(expand: ["owner"])
            loadError = nil
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func setEnabled(_ id: Int, enabled: Bool) async {
        let displayName = items.first(where: { $0.id == id }).map { "Port \($0.incoming_port)" } ?? "Stream"
        let state: NPMActionState = enabled ? .enabling : .disabling
        actionStates[id] = state
        defer { actionStates[id] = nil }
        do {
            try await client.setStreamEnabled(id: id, enabled: enabled)
            await load()
            InAppNotificationCenter.shared.showSuccess(title: enabled ? "Stream Enabled" : "Stream Disabled", message: displayName)
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure(enabled ? "Enable Stream" : "Disable Stream", error: npmError)
        }
    }

    func delete(_ id: Int) async {
        let displayName = items.first(where: { $0.id == id }).map { "Port \($0.incoming_port)" } ?? "Stream"
        actionStates[id] = .deleting
        defer { actionStates[id] = nil }
        do {
            try await client.deleteStream(id: id)
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Stream Deleted", message: displayName)
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Delete Stream", error: npmError)
        }
    }

    func save(create payload: NPMStreamCreate) async {
        do {
            _ = try await client.createStream(payload)
            loadError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Stream Created", message: "Port \(payload.incoming_port)")
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Create Stream", error: npmError)
        }
    }

    func save(update id: Int, payload: NPMStreamUpdate) async {
        do {
            _ = try await client.updateStream(id: id, payload)
            loadError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Stream Updated", message: "Port \(payload.incoming_port)")
        } catch {
            let npmError = NPMError.from(error)
            loadError = npmError
            InAppNotificationCenter.shared.reportFailure("Update Stream", error: npmError)
        }
    }
}
