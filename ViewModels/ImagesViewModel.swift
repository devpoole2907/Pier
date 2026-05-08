import Foundation
import Observation

@MainActor
@Observable
final class ImagesViewModel {
    private(set) var images: [DockerImage] = []
    private(set) var isLoading = false
    private(set) var isPulling = false
    private(set) var loadError: PortainerError?
    private(set) var pullError: PortainerError?

    var searchText: String = ""

    private let client: PortainerClient
    private let endpointID: Int

    init(client: PortainerClient, endpointID: Int) {
        self.client = client
        self.endpointID = endpointID
    }

    var visibleImages: [DockerImage] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let base = trimmed.isEmpty
            ? images
            : images.filter { image in
                image.repoTags.contains(where: { $0.localizedStandardContains(trimmed) })
                    || image.id.localizedStandardContains(trimmed)
            }
        return base.sorted { $0.created > $1.created }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.images = try await client.listImages(endpointID: endpointID)
            self.loadError = nil
        } catch {
            self.loadError = PortainerError.from(error)
        }
    }

    func delete(_ image: DockerImage, force: Bool = false) async {
        do {
            try await client.deleteImage(endpointID: endpointID, imageID: image.id, force: force)
            await load()
        } catch {
            self.loadError = PortainerError.from(error)
        }
    }

    func delete(_ images: [DockerImage], force: Bool = false) async -> [String] {
        var deletedImageIDs: [String] = []
        var firstError: PortainerError?

        for image in images {
            do {
                try await client.deleteImage(endpointID: endpointID, imageID: image.id, force: force)
                deletedImageIDs.append(image.id)
            } catch {
                if firstError == nil {
                    firstError = PortainerError.from(error)
                }
            }
        }

        await load()

        if let error = firstError {
            self.loadError = error
        }

        return deletedImageIDs
    }

    /// Pulls a `name:tag` reference. If `tag` is omitted defaults to "latest".
    func pull(reference: String) async {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let name = String(parts[0])
        let tag = parts.count > 1 ? String(parts[1]) : "latest"

        isPulling = true
        defer { isPulling = false }
        do {
            try await client.pullImage(endpointID: endpointID, fromImage: name, tag: tag)
            self.pullError = nil
            await load()
        } catch {
            self.pullError = PortainerError.from(error)
        }
    }
}
