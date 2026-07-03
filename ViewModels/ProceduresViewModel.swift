import Foundation
import Observation

/// Loads Komodo procedures and runs them on demand. Tracks in-flight runs per-procedure so the
/// list can show a progress state and disable duplicate taps.
@MainActor
@Observable
final class ProceduresViewModel {
    private(set) var procedures: [Procedure] = []
    private(set) var isLoading = false
    private(set) var loadError: KomodoError?
    private(set) var runningIDs: Set<String> = []

    var searchText: String = ""

    private let client: KomodoClient

    init(client: KomodoClient) {
        self.client = client
    }

    var visibleProcedures: [Procedure] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let base = trimmed.isEmpty
            ? procedures
            : procedures.filter { $0.name.localizedStandardContains(trimmed) }
        return base.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func isRunning(_ procedure: Procedure) -> Bool {
        runningIDs.contains(procedure.id)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            procedures = try await client.listProcedures()
            loadError = nil
        } catch {
            loadError = KomodoError.from(error)
        }
    }

    func run(_ procedure: Procedure) async {
        runningIDs.insert(procedure.id)
        defer { runningIDs.remove(procedure.id) }
        do {
            try await client.runProcedure(id: procedure.id)
            loadError = nil
            await load()
        } catch {
            loadError = KomodoError.from(error)
        }
    }
}
