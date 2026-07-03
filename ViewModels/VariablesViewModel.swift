import Foundation
import Observation

/// Loads Komodo global variables (key/value pairs on the Core) for the Variables feature.
/// Read-only - there is no create/update/delete client method available yet, only
/// `listVariables()`.
@MainActor
@Observable
final class VariablesViewModel {
    private(set) var variables: [KomodoVariable] = []
    private(set) var isLoading = false
    private(set) var loadError: KomodoError?

    var searchText: String = ""

    private let client: KomodoClient

    init(client: KomodoClient) {
        self.client = client
    }

    var isEmpty: Bool {
        variables.isEmpty
    }

    /// True when there are variables loaded but the current search filters out all of them.
    var hasNoSearchResults: Bool {
        !isEmpty && filteredVariables.isEmpty
    }

    /// Variables matching the current search text, sorted alphabetically by name.
    var filteredVariables: [KomodoVariable] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let base = trimmed.isEmpty
            ? variables
            : variables.filter { $0.name.localizedStandardContains(trimmed) }
        return base.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            variables = try await client.listVariables()
            loadError = nil
        } catch {
            loadError = KomodoError.from(error)
        }
    }
}
