import SwiftUI

/// A Komodo alert, from `/read/ListAlerts` (response is the paged wrapper `{alerts, next_page}`;
/// see `AlertListResponse`).
nonisolated struct KomodoAlert: Identifiable, Sendable, Hashable {
    let id: String
    let ts: Date
    let resolved: Bool
    let level: AlertLevel
    let targetType: String
    let targetID: String
    let variant: String
    let resolvedTS: Date?
    let summary: String

    private enum CodingKeys: String, CodingKey {
        case oid = "_id"
        case ts
        case resolved
        case level
        case target
        case data
        case resolvedTS = "resolved_ts"
    }

    private enum OIDKeys: String, CodingKey {
        case oid = "$oid"
    }

    private enum TargetKeys: String, CodingKey {
        case type
        case id
    }

    private enum DataKeys: String, CodingKey {
        case type
        case data
    }

    private enum InnerDataKeys: String, CodingKey {
        case name
    }
}

extension KomodoAlert: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let oidContainer = try? container.nestedContainer(keyedBy: OIDKeys.self, forKey: .oid),
           let oid = try? oidContainer.decodeIfPresent(String.self, forKey: .oid) {
            self.id = oid
        } else {
            self.id = try container.decodeIfPresent(String.self, forKey: .oid) ?? UUID().uuidString
        }

        if let tsMillis = try container.decodeIfPresent(Double.self, forKey: .ts), tsMillis > 0 {
            self.ts = Date(timeIntervalSince1970: tsMillis / 1000)
        } else {
            self.ts = .now
        }

        self.resolved = try container.decodeIfPresent(Bool.self, forKey: .resolved) ?? false
        let rawLevel = try container.decodeIfPresent(String.self, forKey: .level)
        self.level = AlertLevel(rawLevel: rawLevel)

        if let target = try? container.nestedContainer(keyedBy: TargetKeys.self, forKey: .target) {
            self.targetType = try target.decodeIfPresent(String.self, forKey: .type) ?? ""
            self.targetID = try target.decodeIfPresent(String.self, forKey: .id) ?? ""
        } else {
            self.targetType = ""
            self.targetID = ""
        }

        var variant = ""
        var innerName: String?
        if let data = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data) {
            variant = try data.decodeIfPresent(String.self, forKey: .type) ?? ""
            if let inner = try? data.nestedContainer(keyedBy: InnerDataKeys.self, forKey: .data) {
                innerName = try? inner.decodeIfPresent(String.self, forKey: .name)
            }
        }
        self.variant = variant

        if let resolvedMillis = try container.decodeIfPresent(Double.self, forKey: .resolvedTS), resolvedMillis > 0 {
            self.resolvedTS = Date(timeIntervalSince1970: resolvedMillis / 1000)
        } else {
            self.resolvedTS = nil
        }

        let humanVariant = variant.isEmpty ? "Alert" : variant
        if let innerName, !innerName.isEmpty {
            self.summary = "\(humanVariant) — \(innerName)"
        } else {
            self.summary = humanVariant
        }
    }
}

/// `ListAlerts` returns a paged wrapper, not a bare array.
nonisolated struct AlertListResponse: Sendable {
    let alerts: [KomodoAlert]
    let nextPage: Int?

    private enum CodingKeys: String, CodingKey {
        case alerts
        case nextPage = "next_page"
    }
}

extension AlertListResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.alerts = try container.decodeIfPresent([KomodoAlert].self, forKey: .alerts) ?? []
        self.nextPage = try container.decodeIfPresent(Int.self, forKey: .nextPage)
    }
}

/// Normalized alert severity, from `level`.
nonisolated enum AlertLevel: String, Sendable, CaseIterable {
    case ok = "OK"
    case warning = "WARNING"
    case critical = "CRITICAL"
    case unknown

    init(rawLevel: String?) {
        guard let rawLevel else {
            self = .unknown
            return
        }
        self = AlertLevel(rawValue: rawLevel) ?? .unknown
    }

    var label: String {
        switch self {
        case .ok: "OK"
        case .warning: "Warning"
        case .critical: "Critical"
        case .unknown: "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .ok: .green
        case .warning: .orange
        case .critical: .red
        case .unknown: .gray
        }
    }
}
