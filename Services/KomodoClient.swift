import Foundation
import OSLog

/// All network access for a single Komodo Core host. Each host gets its own actor instance, so
/// the URLSession and cached credentials are isolated per-host.
///
/// Komodo auth is stateless header auth (`X-Api-Key` / `X-Api-Secret`) - there is no JWT, no
/// login call, and no 401-retry/re-auth loop needed. Every route is a `POST` with
/// a small JSON body, so the client exposes one generic decode-returning call and one
/// void-returning call, with all typed methods built on top of them.
actor KomodoClient {
    nonisolated private static let logger = Logger(subsystem: "com.poole.james.pier", category: "networking")

    let hostID: UUID
    private let baseURL: URL
    private let apiKey: String?
    private let apiSecret: String?
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(host: Host, apiKey: String? = nil, apiSecret: String? = nil, allowsInsecureTLS: Bool = false) throws {
        let trimmedBaseURL = host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawURL = URL(string: trimmedBaseURL) else {
            throw KomodoError.invalidURL
        }
        let url = Self.sanitizedBaseURL(from: rawURL)
        self.hostID = host.id
        self.baseURL = url
        self.apiKey = apiKey ?? (try? KeychainService.apiKey(for: host.id))
        self.apiSecret = apiSecret ?? (try? KeychainService.apiSecret(for: host.id))

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = false
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never

        if allowsInsecureTLS {
            // Use the delegate-driven session that allows self-signed certs.
            self.session = URLSession(configuration: config, delegate: InsecureTLSDelegate(), delegateQueue: nil)
        } else {
            self.session = URLSession(configuration: config)
        }

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Connection test

    /// Verifies the current API key/secret work by listing servers. Used by the host editor.
    func testConnection() async throws -> [KomodoServer] {
        try await listServers()
    }

    // MARK: - Servers

    func listServers() async throws -> [KomodoServer] {
        try await call("/read/ListServers", KomodoEmptyBody())
    }

    func serverState(serverID: String) async throws -> ServerState {
        let response: ServerStateResponse = try await call("/read/GetServerState", ServerIDBody(server: serverID))
        return ServerState(rawState: response.status)
    }

    func systemStats(serverID: String) async throws -> ServerSystemStats {
        try await call("/read/GetSystemStats", ServerIDBody(server: serverID))
    }

    /// Historical (timeseries) stats for charts. Optional feature - decodes defensively and
    /// returns an empty array rather than throwing if the shape ever changes upstream.
    func historicalStats(serverID: String, granularity: String, page: Int = 0) async throws -> [SystemStatsSample] {
        let response: HistoricalStatsResponse = try await call(
            "/read/GetHistoricalServerStats",
            HistoricalStatsBody(server: serverID, granularity: granularity, page: page)
        )
        return response.stats
    }

    // MARK: - Containers

    /// Lists containers on a single server, or across all servers when `serverID` is `nil`.
    func listContainers(serverID: String?) async throws -> [Container] {
        if let serverID {
            return try await call("/read/ListDockerContainers", ServerIDBody(server: serverID))
        }
        return try await call("/read/ListAllDockerContainers", ListAllContainersBody(servers: [], containers: []))
    }

    func inspectContainer(serverID: String, containerID: String) async throws -> ContainerDetail {
        try await call("/read/InspectDockerContainer", ServerContainerBody(server: serverID, container: containerID))
    }

    /// A snapshot of the container's log tail. Komodo has no follow stream; "Follow" in the UI
    /// is implemented as a poll loop that re-calls this on an interval.
    func containerLog(serverID: String, containerID: String, tail: Int = 200) async throws -> ContainerLog {
        try await call("/read/GetContainerLog", ContainerLogBody(server: serverID, container: containerID, tail: tail))
    }

    func searchContainerLog(serverID: String, containerID: String, terms: [String]) async throws -> ContainerLog {
        try await call(
            "/read/SearchContainerLog",
            SearchContainerLogBody(server: serverID, container: containerID, terms: terms)
        )
    }

    func startContainer(serverID: String, containerID: String) async throws {
        try await callVoid("/execute/StartContainer", ServerContainerBody(server: serverID, container: containerID))
    }

    func stopContainer(serverID: String, containerID: String, signal: String? = nil, time: Int? = nil) async throws {
        try await callVoid(
            "/execute/StopContainer",
            ContainerStopBody(server: serverID, container: containerID, signal: signal, time: time)
        )
    }

    func restartContainer(serverID: String, containerID: String) async throws {
        try await callVoid("/execute/RestartContainer", ServerContainerBody(server: serverID, container: containerID))
    }

    func pauseContainer(serverID: String, containerID: String) async throws {
        try await callVoid("/execute/PauseContainer", ServerContainerBody(server: serverID, container: containerID))
    }

    func unpauseContainer(serverID: String, containerID: String) async throws {
        try await callVoid("/execute/UnpauseContainer", ServerContainerBody(server: serverID, container: containerID))
    }

    func destroyContainer(serverID: String, containerID: String, signal: String? = nil, time: Int? = nil) async throws {
        try await callVoid(
            "/execute/DestroyContainer",
            ContainerStopBody(server: serverID, container: containerID, signal: signal, time: time)
        )
    }

    // MARK: - Images

    func listImages(serverID: String) async throws -> [DockerImage] {
        try await call("/read/ListDockerImages", ServerIDBody(server: serverID))
    }

    func deleteImage(serverID: String, name: String) async throws {
        try await callVoid("/execute/DeleteImage", ServerImageNameBody(server: serverID, name: name))
    }

    func pruneImages(serverID: String) async throws {
        try await callVoid("/execute/PruneImages", ServerIDBody(server: serverID))
    }

    // MARK: - Volumes & Networks

    func listVolumes(serverID: String) async throws -> [Volume] {
        try await call("/read/ListDockerVolumes", ServerIDBody(server: serverID))
    }

    func listNetworks(serverID: String) async throws -> [DockerNetwork] {
        try await call("/read/ListDockerNetworks", ServerIDBody(server: serverID))
    }

    // MARK: - Stacks

    func listStacks() async throws -> [Stack] {
        try await call("/read/ListStacks", KomodoEmptyBody())
    }

    func getStack(id: String) async throws -> StackDetail {
        try await call("/read/GetStack", StackIDBody(stack: id))
    }

    /// The stack's primary compose file, read from `GetStack`'s `deployed_contents`
    /// (falling back to `remote_contents`).
    func stackFile(stackID: String) async throws -> (path: String, contents: String)? {
        let detail = try await getStack(id: stackID)
        guard let file = detail.primaryFile else { return nil }
        return (file.path, file.contents)
    }

    func writeStackFile(stackID: String, path: String, contents: String) async throws {
        try await callVoid(
            "/write/WriteStackFileContents",
            WriteStackFileBody(stack: stackID, file_path: path, contents: contents)
        )
    }

    func listStackServices(stackID: String) async throws -> [StackService] {
        try await call("/read/ListStackServices", StackIDBody(stack: stackID))
    }

    func deployStack(stackID: String, services: [String]? = nil, stopTime: Int? = nil) async throws {
        try await callVoid(
            "/execute/DeployStack",
            StackActionBody(stack: stackID, services: services, stop_time: stopTime, remove_orphans: nil)
        )
    }

    func deployStackIfChanged(stackID: String, stopTime: Int? = nil) async throws {
        try await callVoid(
            "/execute/DeployStackIfChanged",
            StackActionBody(stack: stackID, services: nil, stop_time: stopTime, remove_orphans: nil)
        )
    }

    func pullStack(stackID: String, services: [String]? = nil) async throws {
        try await callVoid(
            "/execute/PullStack",
            StackActionBody(stack: stackID, services: services, stop_time: nil, remove_orphans: nil)
        )
    }

    func startStack(stackID: String, services: [String]? = nil) async throws {
        try await callVoid(
            "/execute/StartStack",
            StackActionBody(stack: stackID, services: services, stop_time: nil, remove_orphans: nil)
        )
    }

    func stopStack(stackID: String, services: [String]? = nil, stopTime: Int? = nil) async throws {
        try await callVoid(
            "/execute/StopStack",
            StackActionBody(stack: stackID, services: services, stop_time: stopTime, remove_orphans: nil)
        )
    }

    func restartStack(stackID: String, services: [String]? = nil) async throws {
        try await callVoid(
            "/execute/RestartStack",
            StackActionBody(stack: stackID, services: services, stop_time: nil, remove_orphans: nil)
        )
    }

    func pauseStack(stackID: String, services: [String]? = nil) async throws {
        try await callVoid(
            "/execute/PauseStack",
            StackActionBody(stack: stackID, services: services, stop_time: nil, remove_orphans: nil)
        )
    }

    func unpauseStack(stackID: String, services: [String]? = nil) async throws {
        try await callVoid(
            "/execute/UnpauseStack",
            StackActionBody(stack: stackID, services: services, stop_time: nil, remove_orphans: nil)
        )
    }

    func destroyStack(stackID: String, services: [String]? = nil, stopTime: Int? = nil, removeOrphans: Bool? = nil) async throws {
        try await callVoid(
            "/execute/DestroyStack",
            StackActionBody(stack: stackID, services: services, stop_time: stopTime, remove_orphans: removeOrphans)
        )
    }

    // MARK: - Alerts

    func listAlerts() async throws -> [KomodoAlert] {
        let response: AlertListResponse = try await call("/read/ListAlerts", KomodoEmptyBody())
        return response.alerts
    }

    // MARK: - Procedures

    func listProcedures() async throws -> [Procedure] {
        try await call("/read/ListProcedures", KomodoEmptyBody())
    }

    func runProcedure(id: String) async throws {
        try await callVoid("/execute/RunProcedure", ProcedureIDBody(procedure: id))
    }

    // MARK: - Deployments

    func listDeployments() async throws -> [Deployment] {
        try await call("/read/ListDeployments", KomodoEmptyBody())
    }

    func deployDeployment(id: String) async throws {
        try await callVoid("/execute/Deploy", DeploymentIDBody(deployment: id))
    }

    func startDeployment(id: String) async throws {
        try await callVoid("/execute/StartDeployment", DeploymentIDBody(deployment: id))
    }

    func stopDeployment(id: String, signal: String? = nil, time: Int? = nil) async throws {
        try await callVoid("/execute/StopDeployment", DeploymentStopBody(deployment: id, signal: signal, time: time))
    }

    func restartDeployment(id: String) async throws {
        try await callVoid("/execute/RestartDeployment", DeploymentIDBody(deployment: id))
    }

    func pauseDeployment(id: String) async throws {
        try await callVoid("/execute/PauseDeployment", DeploymentIDBody(deployment: id))
    }

    func unpauseDeployment(id: String) async throws {
        try await callVoid("/execute/UnpauseDeployment", DeploymentIDBody(deployment: id))
    }

    func destroyDeployment(id: String, signal: String? = nil, time: Int? = nil) async throws {
        try await callVoid("/execute/DestroyDeployment", DeploymentStopBody(deployment: id, signal: signal, time: time))
    }

    func pullDeployment(id: String) async throws {
        try await callVoid("/execute/PullDeployment", DeploymentIDBody(deployment: id))
    }

    // MARK: - Variables

    func listVariables() async throws -> [KomodoVariable] {
        try await call("/read/ListVariables", KomodoEmptyBody())
    }

    // MARK: - Generic core

    private func call<Req: Encodable, Res: Decodable>(_ path: String, _ body: Req) async throws -> Res {
        let request = try makeRequest(path: path, body: body)
        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw KomodoError.serverError(code: -1, message: "Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: http, data: data)
        }
        do {
            return try decoder.decode(Res.self, from: data)
        } catch let error as DecodingError {
            throw KomodoError.decoding(String(describing: error))
        }
    }

    private func callVoid<Req: Encodable>(_ path: String, _ body: Req) async throws {
        let request = try makeRequest(path: path, body: body)
        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw KomodoError.serverError(code: -1, message: "Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: http, data: data)
        }
    }

    private func makeRequest<Req: Encodable>(path: String, body: Req) throws -> URLRequest {
        guard let apiKey, let apiSecret else {
            throw KomodoError.apiKeyMissing
        }
        let normalizedBaseURL = normalizedBaseURL(from: baseURL)
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: trimmedPath, relativeTo: normalizedBaseURL)?.absoluteURL else {
            throw KomodoError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue(apiSecret, forHTTPHeaderField: "X-Api-Secret")
        request.httpBody = try encoder.encode(body)
        Self.logger.debug("Prepared POST \(path, privacy: .public) request for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                Self.logger.debug("Received \(http.statusCode) for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
            }
            return (data, response)
        } catch let error as URLError {
            Self.logger.error("Network error for host \(self.hostID.uuidString, privacy: .private(mask: .hash)): \(error.localizedDescription, privacy: .private)")
            throw KomodoError.network(error)
        }
    }

    private func mapStatusError(response: HTTPURLResponse, data: Data?) -> KomodoError {
        let message = responseMessage(from: data)
        if let message {
            Self.logger.error("HTTP \(response.statusCode) for host \(self.hostID.uuidString, privacy: .private(mask: .hash)): \(message, privacy: .private)")
        } else {
            Self.logger.error("HTTP \(response.statusCode) for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
        }
        return switch response.statusCode {
        case 401, 403: .unauthorized
        case 404: .notFound
        default: .serverError(code: response.statusCode, message: message)
        }
    }

    /// Komodo's error body (400/401/403/404/500) is consistently `{ "error": "...", "trace": [...] }`.
    private func responseMessage(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        if let body = try? JSONDecoder().decode(KomodoErrorBody.self, from: data), let error = body.error {
            return error
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(200)
            .description
    }

    private func normalizedBaseURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        if !components.path.isEmpty, !components.path.hasSuffix("/") {
            components.path += "/"
        } else if components.path.isEmpty {
            components.path = "/"
        }
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }

    /// Komodo Core's routes hang directly off the bare origin (no `/api` prefix to strip) - so
    /// we only trim whitespace/trailing slashes and drop any accidental query/fragment, without
    /// otherwise touching the path.
    nonisolated private static func sanitizedBaseURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = path.isEmpty ? "" : "/" + path
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }
}
