import Foundation
import Observation

/// Loads and organizes Komodo alerts for the Alerts feature. Read-only - there is no
/// acknowledge/dismiss action, only the active (unresolved) / resolved split Komodo itself tracks.
@MainActor
@Observable
final class AlertsViewModel {
    private(set) var alerts: [KomodoAlert] = []
    private(set) var isLoading = false
    private(set) var loadError: KomodoError?

    var searchText: String = ""

    private let client: KomodoClient

    init(client: KomodoClient) {
        self.client = client
    }

    var isEmpty: Bool {
        alerts.isEmpty
    }

    /// True when there are alerts loaded but the current search filters out all of them.
    var hasNoSearchResults: Bool {
        !isEmpty && activeAlerts.isEmpty && resolvedAlerts.isEmpty
    }

    /// Unresolved alerts, most recent first.
    var activeAlerts: [KomodoAlert] {
        filtered(alerts.filter { !$0.resolved })
    }

    /// Resolved alerts, most recent first.
    var resolvedAlerts: [KomodoAlert] {
        filtered(alerts.filter(\.resolved))
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            alerts = try await client.listAlerts()
            loadError = nil
        } catch {
            loadError = KomodoError.from(error)
        }
    }

    private func filtered(_ source: [KomodoAlert]) -> [KomodoAlert] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let base = trimmed.isEmpty
            ? source
            : source.filter {
                $0.summary.localizedStandardContains(trimmed)
                    || $0.targetType.localizedStandardContains(trimmed)
            }
        return base.sorted { $0.ts > $1.ts }
    }
}
