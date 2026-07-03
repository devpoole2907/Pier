import Foundation

/// A Komodo procedure - an ordered sequence of stages/actions - from `/read/ListProcedures`.
/// Run via `/execute/RunProcedure`.
nonisolated struct Procedure: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let stages: Int
    let state: String
    let lastRunAt: Date?
    let nextScheduledRun: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case info
    }

    private enum InfoKeys: String, CodingKey {
        case stages
        case state
        case lastRunAt = "last_run_at"
        case nextScheduledRun = "next_scheduled_run"
    }
}

extension Procedure: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""

        let info = try container.nestedContainer(keyedBy: InfoKeys.self, forKey: .info)
        self.stages = try info.decodeIfPresent(Int.self, forKey: .stages) ?? 0
        self.state = try info.decodeIfPresent(String.self, forKey: .state) ?? "Unknown"

        if let lastRunMillis = try info.decodeIfPresent(Double.self, forKey: .lastRunAt), lastRunMillis > 0 {
            self.lastRunAt = Date(timeIntervalSince1970: lastRunMillis / 1000)
        } else {
            self.lastRunAt = nil
        }

        if let nextRunMillis = try info.decodeIfPresent(Double.self, forKey: .nextScheduledRun), nextRunMillis > 0 {
            self.nextScheduledRun = Date(timeIntervalSince1970: nextRunMillis / 1000)
        } else {
            self.nextScheduledRun = nil
        }
    }
}
