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
        let state: NPMActionState = enabled ? .enabling : .disabling
        actionStates[id] = state
        defer { actionStates[id] = nil }
        do {
            try await client.setStreamEnabled(id: id, enabled: enabled)
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func delete(_ id: Int) async {
        actionStates[id] = .deleting
        defer { actionStates[id] = nil }
        do {
            try await client.deleteStream(id: id)
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func save(create payload: NPMStreamCreate) async {
        do {
            _ = try await client.createStream(payload)
            loadError = nil
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }

    func save(update id: Int, payload: NPMStreamUpdate) async {
        do {
            _ = try await client.updateStream(id: id, payload)
            loadError = nil
            await load()
        } catch {
            loadError = NPMError.from(error)
        }
    }
}
