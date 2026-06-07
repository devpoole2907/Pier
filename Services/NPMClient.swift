@preconcurrency import Foundation
@preconcurrency import OSLog

/// All network access for a single Nginx Proxy Manager host. Each host gets its own actor instance,
/// so JWT/api-token state and the URLSession are isolated per-host.
actor NPMClient {
    nonisolated private static let logger = Logger(subsystem: "com.poole.james.pier", category: "npm.networking")

    let hostID: UUID
    private let baseURL: URL
    private let authMethod: NPMAuthMethod
    private let identity: String
    private var jwt: String?
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// In password mode, the cached password is used for silent JWT refresh on 401.
    private var cachedPassword: String?
    /// In token mode, the API token is stored directly as the JWT bearer value.
    private var tokenMode: Bool { authMethod == .token }

    init(host: NPMHost, secret: String? = nil, allowsInsecureTLS: Bool = false) throws {
        let trimmedBaseURL = host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawURL = URL(string: trimmedBaseURL) else {
            throw NPMError.invalidURL
        }
        let url = Self.sanitizedBaseURL(from: rawURL)
        self.hostID = host.id
        self.baseURL = url
        self.authMethod = host.authMethod
        self.identity = host.identity

        if host.authMethod == .token {
            self.jwt = secret ?? (try? KeychainService.npmAPIToken(for: host.id))
        } else {
            self.cachedPassword = secret ?? (try? KeychainService.npmPassword(for: host.id))
            self.jwt = try? KeychainService.npmJWT(for: host.id)
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = false
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never

        if allowsInsecureTLS {
            self.session = URLSession(configuration: config, delegate: InsecureTLSDelegate(), delegateQueue: nil)
        } else {
            self.session = URLSession(configuration: config)
        }

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Auth

    func authenticate(secret: String) async throws {
        if authMethod == .token {
            try await authenticateWithToken(secret)
        } else {
            try await authenticateWithPassword(secret)
        }
    }

    private func authenticateWithPassword(_ password: String) async throws {
        cachedPassword = password
        let body = ["identity": identity, "secret": password]
        let request = try makeRequest(path: "/api/tokens", method: "POST", encodableBody: body, requiresAuth: false)

        Self.logger.info("Authenticating NPM host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw NPMError.serverError(code: -1, message: "Invalid response")
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 422 {
                throw NPMError.unauthorized
            }
            throw mapStatusError(response: http, data: data)
        }

        do {
            let token = try decoder.decode(NPMToken.self, from: data)
            self.jwt = token.token
            try KeychainService.storeNPMJWT(token: token.token, for: hostID)
            try KeychainService.storeNPMPassword(password: password, for: hostID)
            Self.logger.info("Stored NPM JWT for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
        } catch let error as DecodingError {
            throw NPMError.decoding(String(describing: error))
        }
    }

    private func authenticateWithToken(_ token: String) async throws {
        self.jwt = token
        try KeychainService.storeNPMAPIToken(token: token, for: hostID)
        // Validate the token with a ping
        _ = try await ping()
        Self.logger.info("Stored NPM API token for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
    }

    /// Lightweight connection test.
    func ping() async throws -> NPMVersion {
        try await get("/api/")
    }

    // MARK: - Proxy Hosts

    func listProxyHosts(expand: [String] = []) async throws -> [NPMProxyHost] {
        try await get("/api/nginx/proxy-hosts", query: expandQuery(expand))
    }

    func createProxyHost(_ payload: NPMProxyHostCreate) async throws -> NPMProxyHost {
        try await post("/api/nginx/proxy-hosts", body: payload)
    }

    func getProxyHost(id: Int, expand: [String] = []) async throws -> NPMProxyHost {
        try await get("/api/nginx/proxy-hosts/\(id)", query: expandQuery(expand))
    }

    func updateProxyHost(id: Int, _ payload: NPMProxyHostUpdate) async throws -> NPMProxyHost {
        try await put("/api/nginx/proxy-hosts/\(id)", body: payload)
    }

    func deleteProxyHost(id: Int) async throws {
        try await delete("/api/nginx/proxy-hosts/\(id)")
    }

    func setProxyHostEnabled(id: Int, enabled: Bool) async throws {
        let action = enabled ? "enable" : "disable"
        try await postNoContent("/api/nginx/proxy-hosts/\(id)/\(action)")
    }

    // MARK: - Redirection Hosts

    func listRedirectionHosts(expand: [String] = []) async throws -> [NPMRedirectionHost] {
        try await get("/api/nginx/redirection-hosts", query: expandQuery(expand))
    }

    func createRedirectionHost(_ payload: NPMRedirectionHostCreate) async throws -> NPMRedirectionHost {
        try await post("/api/nginx/redirection-hosts", body: payload)
    }

    func getRedirectionHost(id: Int, expand: [String] = []) async throws -> NPMRedirectionHost {
        try await get("/api/nginx/redirection-hosts/\(id)", query: expandQuery(expand))
    }

    func updateRedirectionHost(id: Int, _ payload: NPMRedirectionHostUpdate) async throws -> NPMRedirectionHost {
        try await put("/api/nginx/redirection-hosts/\(id)", body: payload)
    }

    func deleteRedirectionHost(id: Int) async throws {
        try await delete("/api/nginx/redirection-hosts/\(id)")
    }

    func setRedirectionHostEnabled(id: Int, enabled: Bool) async throws {
        let action = enabled ? "enable" : "disable"
        try await postNoContent("/api/nginx/redirection-hosts/\(id)/\(action)")
    }

    // MARK: - Dead Hosts

    func listDeadHosts(expand: [String] = []) async throws -> [NPMDeadHost] {
        try await get("/api/nginx/dead-hosts", query: expandQuery(expand))
    }

    func createDeadHost(_ payload: NPMDeadHostCreate) async throws -> NPMDeadHost {
        try await post("/api/nginx/dead-hosts", body: payload)
    }

    func getDeadHost(id: Int, expand: [String] = []) async throws -> NPMDeadHost {
        try await get("/api/nginx/dead-hosts/\(id)", query: expandQuery(expand))
    }

    func updateDeadHost(id: Int, _ payload: NPMDeadHostUpdate) async throws -> NPMDeadHost {
        try await put("/api/nginx/dead-hosts/\(id)", body: payload)
    }

    func deleteDeadHost(id: Int) async throws {
        try await delete("/api/nginx/dead-hosts/\(id)")
    }

    func setDeadHostEnabled(id: Int, enabled: Bool) async throws {
        let action = enabled ? "enable" : "disable"
        try await postNoContent("/api/nginx/dead-hosts/\(id)/\(action)")
    }

    // MARK: - Streams

    func listStreams(expand: [String] = []) async throws -> [NPMStream] {
        try await get("/api/nginx/streams", query: expandQuery(expand))
    }

    func createStream(_ payload: NPMStreamCreate) async throws -> NPMStream {
        try await post("/api/nginx/streams", body: payload)
    }

    func getStream(id: Int, expand: [String] = []) async throws -> NPMStream {
        try await get("/api/nginx/streams/\(id)", query: expandQuery(expand))
    }

    func updateStream(id: Int, _ payload: NPMStreamUpdate) async throws -> NPMStream {
        try await put("/api/nginx/streams/\(id)", body: payload)
    }

    func deleteStream(id: Int) async throws {
        try await delete("/api/nginx/streams/\(id)")
    }

    func setStreamEnabled(id: Int, enabled: Bool) async throws {
        let action = enabled ? "enable" : "disable"
        try await postNoContent("/api/nginx/streams/\(id)/\(action)")
    }

    // MARK: - Access Lists

    func listAccessLists(expand: [String] = []) async throws -> [NPMAccessList] {
        try await get("/api/nginx/access-lists", query: expandQuery(expand))
    }

    func createAccessList(_ payload: NPMAccessListCreate) async throws -> NPMAccessList {
        try await post("/api/nginx/access-lists", body: payload)
    }

    func getAccessList(id: Int, expand: [String] = []) async throws -> NPMAccessList {
        try await get("/api/nginx/access-lists/\(id)", query: expandQuery(expand))
    }

    func updateAccessList(id: Int, _ payload: NPMAccessListUpdate) async throws -> NPMAccessList {
        try await put("/api/nginx/access-lists/\(id)", body: payload)
    }

    func deleteAccessList(id: Int) async throws {
        try await delete("/api/nginx/access-lists/\(id)")
    }

    // MARK: - Certificates

    func listCertificates(expand: [String] = []) async throws -> [NPMCertificate] {
        try await get("/api/nginx/certificates", query: expandQuery(expand))
    }

    func createCertificate(_ payload: NPMCertificateCreate) async throws -> NPMCertificate {
        try await post("/api/nginx/certificates", body: payload)
    }

    func getCertificate(id: Int, expand: [String] = []) async throws -> NPMCertificate {
        try await get("/api/nginx/certificates/\(id)", query: expandQuery(expand))
    }

    func deleteCertificate(id: Int) async throws {
        try await delete("/api/nginx/certificates/\(id)")
    }

    func renewCertificate(id: Int) async throws -> NPMCertificate {
        try await post("/api/nginx/certificates/\(id)/renew", body: EmptyBody())
    }

    // MARK: - Generic helpers

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem]? = nil) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", query: query)
        let (data, response) = try await performAuthenticated(request, idempotent: true)
        let http = response as? HTTPURLResponse
        guard let http, (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: http, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw NPMError.decoding(String(describing: error))
        }
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B, query: [URLQueryItem]? = nil) async throws -> T {
        let request = try makeRequest(path: path, method: "POST", encodableBody: body, query: query)
        let (data, response) = try await performAuthenticated(request)
        let http = response as? HTTPURLResponse
        guard let http, (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: http, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw NPMError.decoding(String(describing: error))
        }
    }

    private func put<T: Decodable, B: Encodable>(_ path: String, body: B, query: [URLQueryItem]? = nil) async throws -> T {
        let request = try makeRequest(path: path, method: "PUT", encodableBody: body, query: query)
        let (data, response) = try await performAuthenticated(request)
        let http = response as? HTTPURLResponse
        guard let http, (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: http, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw NPMError.decoding(String(describing: error))
        }
    }

    private func postNoContent(_ path: String) async throws {
        let request = try makeRequest(path: path, method: "POST")
        let (data, response) = try await performAuthenticated(request)
        let http = response as? HTTPURLResponse
        guard let http, (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: http, data: data)
        }
    }

    private func delete(_ path: String) async throws {
        let request = try makeRequest(path: path, method: "DELETE")
        let (data, response) = try await performAuthenticated(request)
        let http = response as? HTTPURLResponse
        guard let http, (200...299).contains(http.statusCode) else {
            throw mapStatusError(response: http, data: data)
        }
    }

    // MARK: - Request building

    private func makeRequest(path: String, method: String, encodableBody: (any Encodable)? = nil, query: [URLQueryItem]? = nil, requiresAuth: Bool = true) throws -> URLRequest {
        let normalizedBaseURL = normalizedBaseURL(from: baseURL)
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        var components = URLComponents(url: normalizedBaseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.path ?? ""
        components?.path = basePath + trimmedPath
        components?.queryItems = query

        guard let url = components?.url else {
            throw NPMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = encodableBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try encoder.encode(AnyEncodable(body))
            } catch {
                throw NPMError.decoding("Failed to encode request body: \(error)")
            }
        }
        if requiresAuth, let jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func performRequest(_ request: URLRequest, retryTransient: Bool = false) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                Self.logger.debug("NPM received \(http.statusCode) for host \(self.hostID.uuidString, privacy: .private(mask: .hash))")
            }
            return (data, response)
        } catch let error as URLError {
            // A stale pooled keep-alive socket surfaces as a timeout or dropped connection on the
            // first request after idle. For idempotent calls, retry once on a fresh connection.
            if retryTransient, Self.isTransient(error) {
                Self.logger.notice("NPM transient network error (\(error.code.rawValue)) for host \(self.hostID.uuidString, privacy: .private(mask: .hash)); retrying once")
                do {
                    let (data, response) = try await session.data(for: request)
                    return (data, response)
                } catch let retryError as URLError {
                    Self.logger.error("NPM network error after retry for host \(self.hostID.uuidString, privacy: .private(mask: .hash)): \(retryError.localizedDescription, privacy: .private)")
                    throw NPMError.network(retryError)
                }
            }
            Self.logger.error("NPM network error for host \(self.hostID.uuidString, privacy: .private(mask: .hash)): \(error.localizedDescription, privacy: .private)")
            throw NPMError.network(error)
        }
    }

    /// Network failures that commonly indicate a dead/reused connection rather than a hard outage,
    /// and are therefore safe to retry once for idempotent requests.
    nonisolated private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost:
            true
        default:
            false
        }
    }

    /// - Parameter idempotent: when `true` (GETs only), a single transient network failure
    ///   (timeout / dropped connection — typically a stale pooled keep-alive socket) is retried
    ///   on a fresh request. Mutating verbs pass `false` to avoid duplicate writes.
    private func performAuthenticated(_ request: URLRequest, idempotent: Bool = false) async throws -> (Data, URLResponse) {
        let (data, response) = try await performRequest(request, retryTransient: idempotent)
        guard let http = response as? HTTPURLResponse, http.statusCode == 401 else {
            return (data, response)
        }

        if tokenMode {
            throw NPMError.unauthorized
        }

        guard let password = cachedPassword else {
            throw NPMError.unauthorized
        }

        Self.logger.notice("NPM JWT expired for host \(self.hostID.uuidString, privacy: .private(mask: .hash)); reauthenticating")
        try await authenticateWithPassword(password)

        var retried = request
        if let jwt {
            retried.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        return try await performRequest(retried, retryTransient: idempotent)
    }

    private func mapStatusError(response: HTTPURLResponse?, data: Data? = nil) -> NPMError {
        guard let http = response else {
            return .serverError(code: -1, message: nil)
        }
        let message = responseMessage(from: data)
        if let message {
            Self.logger.error("NPM HTTP \(http.statusCode) for host \(self.hostID.uuidString, privacy: .private(mask: .hash)): \(message, privacy: .private)")
        }
        return switch http.statusCode {
        case 401: .unauthorized
        case 404: .notFound
        default: .serverError(code: http.statusCode, message: message)
        }
    }

    private func responseMessage(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let errorObj = payload["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                return message
            }
            if let message = payload["message"] as? String {
                return message
            }
            if let err = payload["error"] as? String {
                return err
            }
            if let msg = payload["msg"] as? String {
                return msg
            }
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(200)
            .description
    }

    private func expandQuery(_ fields: [String]) -> [URLQueryItem]? {
        guard !fields.isEmpty else { return nil }
        return [URLQueryItem(name: "expand", value: fields.joined(separator: ","))]
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

        if path == "api" {
            path = ""
        } else if path.hasSuffix("/api") {
            path.removeLast(4)
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        if path == "auth" || path == "login" {
            path = ""
        }

        components.path = path.isEmpty ? "" : "/" + path
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }
}

// MARK: - Helper types

struct NPMVersion: Sendable, Decodable {
    let status: String?
    let version: VersionInfo?
    struct VersionInfo: Sendable, Decodable {
        let major: Int?
        let minor: Int?
        let revision: Int?
    }
}

/// Empty body for POST requests that require no payload.
private struct EmptyBody: Encodable {}

/// Type-erased Encodable wrapper for generic JSON encoding.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: some Encodable) {
        _encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
