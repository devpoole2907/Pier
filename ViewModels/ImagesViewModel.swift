import Foundation
import Observation

/// A Docker image paired with the Komodo server it was fetched from. Komodo images are strictly
/// per-server - there's no `ListAllDockerImages` the way there is `ListAllDockerContainers` - so
/// "All servers" mode fans out to every reachable server and this pairing is what lets delete
/// target the right server afterwards. When the same image exists on multiple servers it shows up
/// as one `ImageListItem` per server, each independently deletable.
struct ImageListItem: Identifiable, Hashable {
    let image: DockerImage
    let serverID: String

    var id: String { "\(serverID)/\(image.id)" }
}

@MainActor
@Observable
final class ImagesViewModel {
    private(set) var items: [ImageListItem] = []
    private(set) var isLoading = false
    private(set) var isPruning = false
    private(set) var loadError: KomodoError?

    var searchText: String = ""

    private let client: KomodoClient
    /// Scopes the list to a single Komodo server, or `nil` for "All servers".
    private let serverID: String?
    /// Needed only to fan out in "All servers" mode - unlike containers, Komodo has no aggregate
    /// endpoint for images, so this view model has to enumerate servers itself.
    private let servers: [KomodoServer]

    init(client: KomodoClient, serverID: String?, servers: [KomodoServer]) {
        self.client = client
        self.serverID = serverID
        self.servers = servers
    }

    var visibleItems: [ImageListItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let base = trimmed.isEmpty
            ? items
            : items.filter { item in
                item.image.displayName.localizedStandardContains(trimmed)
                    || item.image.id.localizedStandardContains(trimmed)
                    || item.image.tags.contains(where: { $0.localizedStandardContains(trimmed) })
            }
        return base.sorted { $0.image.created > $1.image.created }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let serverID {
                let images = try await client.listImages(serverID: serverID)
                self.items = images.map { ImageListItem(image: $0, serverID: serverID) }
            } else {
                self.items = await loadAllServers()
            }
            self.loadError = nil
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    /// Fetches images from every reachable server concurrently and merges the results. A server
    /// that fails this refresh is silently skipped (mirrors `ServersDashboardViewModel`'s
    /// `loadStats`) rather than failing the whole load - one flaky server shouldn't blank the rest.
    private func loadAllServers() async -> [ImageListItem] {
        let reachable = servers.filter { $0.state == .ok }
        guard !reachable.isEmpty else { return [] }
        return await withTaskGroup(of: [ImageListItem].self) { group in
            for server in reachable {
                group.addTask { [client] in
                    guard let images = try? await client.listImages(serverID: server.id) else { return [] }
                    return images.map { ImageListItem(image: $0, serverID: server.id) }
                }
            }
            var all: [ImageListItem] = []
            for await result in group {
                all.append(contentsOf: result)
            }
            return all
        }
    }

    func delete(_ item: ImageListItem) async {
        do {
            try await client.deleteImage(serverID: item.serverID, name: item.image.name)
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Image Deleted", message: item.image.displayName)
        } catch {
            let komodoError = KomodoError.from(error)
            self.loadError = komodoError
            InAppNotificationCenter.shared.reportFailure("Delete Image", error: komodoError)
        }
    }

    func delete(_ items: [ImageListItem]) async -> [String] {
        var deletedIDs: [String] = []
        var firstError: KomodoError?

        for item in items {
            do {
                try await client.deleteImage(serverID: item.serverID, name: item.image.name)
                deletedIDs.append(item.id)
            } catch {
                if firstError == nil {
                    firstError = KomodoError.from(error)
                }
            }
        }

        await load()

        if let firstError {
            self.loadError = firstError
            InAppNotificationCenter.shared.reportFailure("Delete Images", error: firstError)
        } else if !deletedIDs.isEmpty {
            let message = items.count == 1 ? items[0].image.displayName : "\(deletedIDs.count) images"
            InAppNotificationCenter.shared.showSuccess(title: "Images Deleted", message: message)
        }

        return deletedIDs
    }

    /// Prunes unused images on the active server, or on every reachable server in "All" mode.
    func prune() async {
        isPruning = true
        defer { isPruning = false }
        do {
            if let serverID {
                try await client.pruneImages(serverID: serverID)
            } else {
                for server in servers where server.state == .ok {
                    try await client.pruneImages(serverID: server.id)
                }
            }
            self.loadError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: "Images Pruned", message: "Unused images removed")
        } catch {
            let komodoError = KomodoError.from(error)
            self.loadError = komodoError
            InAppNotificationCenter.shared.reportFailure("Prune Images", error: komodoError)
        }
    }
}
