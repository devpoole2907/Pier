import Foundation
import OSLog

/// All network access for a single Portainer host. Each host gets its own actor instance,
/// so JWT state and the URLSession are isolated per-host.
///
/// The actor exposes typed methods returning Codable models. Streaming endpoints (logs, stats)
/// return `AsyncThrowingStream`s; cancelling the iterator cancels the underlying URLSessionTask.
actor PortainerClient {
    nonisolated private static let logger = Logger(subsystem: "com.poole.james.pier", category: "networking")

    let hostID: UUID
    private let baseURL: URL
    private let username: String
    private var jwt: String?
    private let session: URLSession
    private let decoder: JSONDecoder

    /// `password` is supplied lazily when the token expires and we need to re-auth. If not passed in
    /// directly, we fall back to the Keychain copy saved for seamless relaunches.
    private var cachedPassword: String?

    init(host: Host, password: String? = nil, allowsInsecureTLS: Bool = false) throws {
        let trimmedBaseURL = host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawURL = URL(string: trimmedBaseURL) else {
            throw PortainerError.invalidURL
        }
        let url = Self.sanitizedBaseURL(from: rawURL)
        self.hostID = host.id
        self.baseURL = url
        self.username = host.username
        self.cachedPassword = password ?? (try? KeychainService.password(for: host.id))
        self.jwt = try? KeychainService.token(for: host.id)

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

        self.decoder = JSONDecoder()
    }

    // MARK: - Auth

    /// Authenticates with username + password, stores the JWT in memory and the keychain.
    /// Call this first when adding a new host or if `cachedPassword` becomes available.
    func authenticate(password: String) async throws {
        self.cachedPassword = password
        let body = ["username": username, "password": password]
        let request = try makeRequest(path: "/api/auth", method: "POST", body: body, requiresAuth: false)

        Self.logger.info("Authenticating against host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw PortainerError.serverError(code: -1, message: "Invalid response")
        }
        Self.logger.info("Authentication response \(http.statusCode) for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 422 {
                throw PortainerError.unauthorized
            }
            throw mapStatusError(response: response, data: data)
        }

        do {
            let auth = try decoder.decode(AuthResponse.self, from: data)
            self.jwt = auth.jwt
            try KeychainService.store(token: auth.jwt, for: hostID)
            try KeychainService.store(password: password, for: hostID)
            Self.logger.info("Stored JWT for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
        } catch let error as DecodingError {
            throw PortainerError.decoding(String(describing: error))
        }
    }

    // MARK: - Endpoints

    func listEndpoints() async throws -> [PortainerEndpoint] {
        try await get("/api/endpoints")
    }

    // MARK: - Containers

    func listContainers(endpointID: Int, includeStopped: Bool = true) async throws -> [Container] {
        let suffix = includeStopped ? "?all=1" : ""
        return try await get("/api/endpoints/\(endpointID)/docker/containers/json\(suffix)")
    }

    func inspectContainer(endpointID: Int, containerID: String) async throws -> ContainerDetail {
        try await get("/api/endpoints/\(endpointID)/docker/containers/\(containerID)/json")
    }

    func startContainer(endpointID: Int, containerID: String) async throws {
        try await postNoContent("/api/endpoints/\(endpointID)/docker/containers/\(containerID)/start")
    }

    func stopContainer(endpointID: Int, containerID: String) async throws {
        try await postNoContent("/api/endpoints/\(endpointID)/docker/containers/\(containerID)/stop")
    }

    func restartContainer(endpointID: Int, containerID: String) async throws {
        try await postNoContent("/api/endpoints/\(endpointID)/docker/containers/\(containerID)/restart")
    }

    func killContainer(endpointID: Int, containerID: String) async throws {
        try await postNoContent("/api/endpoints/\(endpointID)/docker/containers/\(containerID)/kill")
    }

    func deleteContainer(endpointID: Int, containerID: String, force: Bool = true, removeVolumes: Bool = false) async throws {
        let path = "/api/endpoints/\(endpointID)/docker/containers/\(containerID)?force=\(force)&v=\(removeVolumes)"
        try await deleteNoContent(path)
    }

    /// Fetches the most recent `tail` lines of combined stdout+stderr.
    func fetchLogs(endpointID: Int, containerID: String, tail: Int = 200) async throws -> String {
        let path = "/api/endpoints/\(endpointID)/docker/containers/\(containerID)/logs?stdout=1&stderr=1&tail=\(tail)&timestamps=0"
        let request = try makeRequest(path: path, method: "GET")
        let (data, response) = try await performAuthenticated(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw mapStatusError(response: response)
        }
        return DockerLogStreamDecoder.decode(data: data)
    }

    /// Streams logs as decoded text lines. Cancellation closes the underlying connection.
    func streamLogs(endpointID: Int, containerID: String, tail: Int = 200) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let path = "/api/endpoints/\(endpointID)/docker/containers/\(containerID)/logs?stdout=1&stderr=1&follow=1&tail=\(tail)&timestamps=0"
                    let request = try makeRequest(path: path, method: "GET")
                    let (bytes, response) = try await performAuthenticatedBytes(request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish(throwing: mapStatusError(response: response))
                        return
                    }
                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)
                        // Flush on newlines so the UI sees lines as they arrive.
                        if byte == 0x0A {
                            let chunk = DockerLogStreamDecoder.decode(data: buffer)
                            buffer.removeAll(keepingCapacity: true)
                            if !chunk.isEmpty {
                                continuation.yield(chunk)
                            }
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Streams CPU/memory/network samples. Newline-delimited JSON over the wire.
    func streamStats(endpointID: Int, containerID: String) -> AsyncThrowingStream<ContainerStats, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let path = "/api/endpoints/\(endpointID)/docker/containers/\(containerID)/stats?stream=true"
                    let request = try makeRequest(path: path, method: "GET")
                    let (bytes, response) = try await performAuthenticatedBytes(request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish(throwing: mapStatusError(response: response))
                        return
                    }
                    let lineDecoder = JSONDecoder()
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8) else { continue }
                        do {
                            let stats = try lineDecoder.decode(ContainerStats.self, from: data)
                            continuation.yield(stats)
                        } catch {
                            // Stats endpoints occasionally emit partial frames during container stop;
                            // skip the frame rather than tearing down the whole stream.
                            continue
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Images

    func listImages(endpointID: Int) async throws -> [DockerImage] {
        try await get("/api/endpoints/\(endpointID)/docker/images/json")
    }

    func deleteImage(endpointID: Int, imageID: String, force: Bool = false) async throws {
        let path = "/api/endpoints/\(endpointID)/docker/images/\(imageID)?force=\(force)"
        try await deleteNoContent(path)
    }

    /// Pulls an image. Docker returns a stream of progress JSON; we drain it for completion.
    func pullImage(endpointID: Int, fromImage: String, tag: String) async throws {
        let escapedFrom = fromImage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fromImage
        let escapedTag = tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tag
        let path = "/api/endpoints/\(endpointID)/docker/images/create?fromImage=\(escapedFrom)&tag=\(escapedTag)"
        let request = try makeRequest(path: path, method: "POST")
        let (bytes, response) = try await performAuthenticatedBytes(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw mapStatusError(response: response)
        }
        for try await _ in bytes.lines { }
    }

    // MARK: - Volumes & Networks

    func listVolumes(endpointID: Int) async throws -> [Volume] {
        let response: VolumeListResponse = try await get("/api/endpoints/\(endpointID)/docker/volumes")
        return response.volumes
    }

    func listNetworks(endpointID: Int) async throws -> [DockerNetwork] {
        try await get("/api/endpoints/\(endpointID)/docker/networks")
    }

    // MARK: - Stacks

    func listStacks() async throws -> [Stack] {
        try await get("/api/stacks")
    }

    func stackFile(stackID: Int) async throws -> String {
        let response: StackFile = try await get("/api/stacks/\(stackID)/file")
        return response.stackFileContent
    }

    func startStack(stackID: Int, endpointID: Int) async throws {
        try await postNoContent("/api/stacks/\(stackID)/start?endpointId=\(endpointID)")
    }

    func stopStack(stackID: Int, endpointID: Int) async throws {
        try await postNoContent("/api/stacks/\(stackID)/stop?endpointId=\(endpointID)")
    }

    func deleteStack(stackID: Int, endpointID: Int) async throws {
        try await deleteNoContent("/api/stacks/\(stackID)?endpointId=\(endpointID)")
    }

    // MARK: - Generic helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "GET")
        let (data, response) = try await performAuthenticated(request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: response, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw PortainerError.decoding(String(describing: error))
        }
    }

    private func postNoContent(_ path: String) async throws {
        let request = try makeRequest(path: path, method: "POST")
        let (data, response) = try await performAuthenticated(request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: response, data: data)
        }
    }

    private func deleteNoContent(_ path: String) async throws {
        let request = try makeRequest(path: path, method: "DELETE")
        let (data, response) = try await performAuthenticated(request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: response, data: data)
        }
    }

    private func makeRequest(path: String, method: String, body: [String: String]? = nil, requiresAuth: Bool = true) throws -> URLRequest {
        let normalizedBaseURL = normalizedBaseURL(from: baseURL)
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: trimmedPath, relativeTo: normalizedBaseURL)?.absoluteURL else {
            throw PortainerError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if requiresAuth, let jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        Self.logger.debug("Prepared \(method, privacy: .public) request for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
        return request
    }

    /// Wraps `performRequest` with a single retry on 401, attempting re-auth via the cached password.
    private func performAuthenticated(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 401 else {
            return (data, response)
        }
        // 401 → try to re-auth once.
        guard let password = cachedPassword else {
            throw PortainerError.unauthorized
        }
        Self.logger.notice("JWT expired for host \(self.hostID.uuidString, privacy: .private(mask: .hash)); reauthenticating")
        try await authenticate(password: password)
        var retried = request
        if let jwt {
            retried.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        return try await performRequest(retried)
    }

    /// Same as `performAuthenticated` but returns the byte stream variant for log/stat streaming.
    private func performAuthenticatedBytes(_ request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 401 else {
                return (bytes, response)
            }
            guard let password = cachedPassword else {
                throw PortainerError.unauthorized
            }
            Self.logger.notice("Streaming request hit 401 for host \(self.hostID.uuidString, privacy: .private(mask: .hash)); reauthenticating")
            try await authenticate(password: password)
            var retried = request
            if let jwt {
                retried.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
            }
            return try await session.bytes(for: retried)
        } catch let error as URLError {
            throw PortainerError.network(error)
        }
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
            throw PortainerError.network(error)
        }
    }

    private func mapStatusError(response: URLResponse, data: Data? = nil) -> PortainerError {
        guard let http = response as? HTTPURLResponse else {
            return .serverError(code: -1, message: nil)
        }
        let message = responseMessage(from: data)
        if let message {
            Self.logger.error("HTTP \(http.statusCode) for host \(self.hostID.uuidString, privacy: .private(mask: .hash)): \(message, privacy: .private)")
        } else {
            Self.logger.error("HTTP \(http.statusCode) for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
        }
        return switch http.statusCode {
        case 401: .unauthorized
        case 404: .notFound
        default: .serverError(code: http.statusCode, message: message)
        }
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

    nonisolated private static func sanitizedBaseURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedFragment = components.fragment?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Users often paste the API root or a login URL copied from the browser.
        if path == "api" {
            path = ""
        } else if path.hasSuffix("/api") {
            path.removeLast(4)
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        if let trimmedFragment, trimmedFragment.contains("auth") || trimmedFragment.contains("login") {
            components.fragment = nil
        }

        if path == "auth" || path == "login" {
            path = ""
        }

        components.path = path.isEmpty ? "" : "/" + path
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }

    private func responseMessage(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = payload["message"] as? String, let details = payload["details"] as? String {
                return "\(message) (\(details))"
            }
            if let message = payload["message"] as? String {
                return message
            }
            if let err = payload["err"] as? String {
                return err
            }
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(200)
            .description
    }
}
