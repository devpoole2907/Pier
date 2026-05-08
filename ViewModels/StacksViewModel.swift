import Foundation
import Observation

@MainActor
@Observable
final class StacksViewModel {
    private(set) var stacks: [Stack] = []
    private(set) var isLoading = false
    private(set) var loadError: PortainerError?
    private(set) var fileContent: String = ""
    private(set) var isLoadingFile = false

    private let client: PortainerClient
    private let endpointID: Int

    init(client: PortainerClient, endpointID: Int) {
        self.client = client
        self.endpointID = endpointID
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.stacks = try await client.listStacks().sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            self.loadError = nil
        } catch {
            self.loadError = PortainerError.from(error)
        }
    }

    func loadFile(for stack: Stack) async {
        isLoadingFile = true
        defer { isLoadingFile = false }
        do {
            self.fileContent = try await client.stackFile(stackID: stack.id)
            self.loadError = nil
        } catch {
            self.loadError = PortainerError.from(error)
        }
    }

    func start(_ stack: Stack) async {
        await performAction { try await self.client.startStack(stackID: stack.id, endpointID: self.endpointID) }
    }

    func stop(_ stack: Stack) async {
        await performAction { try await self.client.stopStack(stackID: stack.id, endpointID: self.endpointID) }
    }

    func delete(_ stack: Stack) async {
        await performAction { try await self.client.deleteStack(stackID: stack.id, endpointID: self.endpointID) }
    }

    func start(_ stacks: [Stack]) async {
        await performActions(stacks) { stack in
            try await self.client.startStack(stackID: stack.id, endpointID: self.endpointID)
        }
    }

    func stop(_ stacks: [Stack]) async {
        await performActions(stacks) { stack in
            try await self.client.stopStack(stackID: stack.id, endpointID: self.endpointID)
        }
    }

    func delete(_ stacks: [Stack]) async {
        await performActions(stacks) { stack in
            try await self.client.deleteStack(stackID: stack.id, endpointID: self.endpointID)
        }
    }

    private func performAction(_ body: @escaping @Sendable () async throws -> Void) async {
        do {
            try await body()
            await load()
        } catch {
            self.loadError = PortainerError.from(error)
        }
    }

    private func performActions(
        _ stacks: [Stack],
        operation: @escaping @Sendable (Stack) async throws -> Void
    ) async {
        do {
            for stack in stacks {
                try await operation(stack)
            }
            await load()
        } catch {
            await load()
            self.loadError = PortainerError.from(error)
        }
    }
}
