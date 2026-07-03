import Foundation

// MARK: - Request bodies for `KomodoClient`
//
// Komodo's API is POST-everywhere with a typed JSON body per route. These are grouped in one
// file (rather than one-per-type) since they are pure wire structs with no behavior, per the
// SPEC's guidance to keep them alongside the client. Optional `Encodable` properties are
// omitted from the encoded JSON automatically by the synthesized conformance, so a single
// generously-optional struct can safely serve several routes whose schemas are subsets of it.
//
// All of these are declared `nonisolated`: the project builds with `-default-isolation
// MainActor`, so a plain struct's *synthesized* `Encodable`/`Decodable` conformance would
// otherwise be MainActor-isolated, which can't be used from within the non-MainActor
// `KomodoClient` actor. Marking the type itself `nonisolated` keeps the synthesized conformance
// (and every member) callable from any isolation context - the same fix used for AppIntents
// data types elsewhere.

/// Used for list endpoints that take no required parameters, e.g. `/read/ListServers`,
/// `/read/ListStacks`, `/read/ListAlerts`, `/read/ListProcedures`, `/read/ListDeployments`,
/// `/read/ListVariables`. (Their OpenAPI schemas mark `query`/`page` required, but the live
/// server accepts `{}` and applies defaults.)
nonisolated struct KomodoEmptyBody: Encodable, Sendable {}

nonisolated struct ServerIDBody: Encodable, Sendable {
    let server: String
}

nonisolated struct HistoricalStatsBody: Encodable, Sendable {
    let server: String
    let granularity: String
    let page: Int
}

nonisolated struct ListAllContainersBody: Encodable, Sendable {
    let servers: [String]
    let containers: [String]
}

nonisolated struct ServerContainerBody: Encodable, Sendable {
    let server: String
    let container: String
}

nonisolated struct ContainerLogBody: Encodable, Sendable {
    let server: String
    let container: String
    let tail: Int
}

nonisolated struct SearchContainerLogBody: Encodable, Sendable {
    let server: String
    let container: String
    let terms: [String]
}

/// Stop/destroy container actions accept an optional termination signal and/or grace period.
nonisolated struct ContainerStopBody: Encodable, Sendable {
    let server: String
    let container: String
    let signal: String?
    let time: Int?
}

nonisolated struct ServerImageNameBody: Encodable, Sendable {
    let server: String
    let name: String
}

nonisolated struct StackIDBody: Encodable, Sendable {
    let stack: String
}

nonisolated struct WriteStackFileBody: Encodable, Sendable {
    let stack: String
    let file_path: String
    let contents: String
}

/// Covers every stack lifecycle route (`DeployStack`, `DeployStackIfChanged`, `PullStack`,
/// `StartStack`, `StopStack`, `RestartStack`, `PauseStack`, `UnpauseStack`, `DestroyStack`).
/// Each route's real schema is a subset of these fields; unused fields are simply left `nil`
/// and omitted from the wire body.
nonisolated struct StackActionBody: Encodable, Sendable {
    let stack: String
    let services: [String]?
    let stop_time: Int?
    let remove_orphans: Bool?
}

nonisolated struct ProcedureIDBody: Encodable, Sendable {
    let procedure: String
}

/// Covers `StartDeployment`, `RestartDeployment`, `PauseDeployment`, `UnpauseDeployment`,
/// `PullDeployment` - all of which take only `{deployment}`.
nonisolated struct DeploymentIDBody: Encodable, Sendable {
    let deployment: String
}

/// Covers `StopDeployment` and `DestroyDeployment`, which additionally accept an optional
/// termination signal and/or grace period (`time`).
nonisolated struct DeploymentStopBody: Encodable, Sendable {
    let deployment: String
    let signal: String?
    let time: Int?
}

// MARK: - Wire response shapes for endpoints with no dedicated model file

/// `/read/GetServerState` → `{ "status": "Ok" | "NotOk" | "Disabled" }`.
nonisolated struct ServerStateResponse: Decodable, Sendable {
    let status: String
}

// MARK: - Wire error shape

/// Komodo's error responses (400/401/403/404/500) all share this shape: `{ "error": "...", "trace": [...] }`.
nonisolated struct KomodoErrorBody: Decodable, Sendable {
    let error: String?
    let trace: [String]?
}
