import Foundation

// MARK: - APIError

/// Errors that can occur during API operations.
enum APIError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, data: Data)
    case unauthorized
    case serverUnreachable
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .httpError(let statusCode, _):
            return "HTTP error with status code \(statusCode)."
        case .unauthorized:
            return "Authentication failed. Please log in again."
        case .serverUnreachable:
            return "The server is unreachable. Check your connection and server address."
        case .decodingError(let error):
            return "Failed to decode server response: \(error.localizedDescription)"
        }
    }
}

// MARK: - ProgressUpdateRequest

/// Request body sent to update media progress for a library item.
/// `isFinished` is optional — when nil it is omitted from the JSON so the server's
/// existing value is preserved. This prevents accidentally un-finishing a book.
struct ProgressUpdateRequest: Codable {
    let progress: Double
    let currentTime: Double
    let duration: Double
    let isFinished: Bool?
}

// MARK: - APIClient

extension Notification.Name {
    /// Posted when an API call returns 401. `userInfo["serverId"]` is the server UUID if known.
    static let apiClientUnauthorized = Notification.Name("apiClientUnauthorized")
}

/// HTTP client for communicating with the Audiobookshelf server API.
final class APIClient {

    // MARK: - Properties

    let baseURL: URL
    let token: String
    let serverId: UUID?
    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Init

    init(baseURL: URL, token: String, serverId: UUID? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.serverId = serverId
        self.session = session

        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    /// Called from request/requestVoid on a 401 response so observers (e.g. ServerService)
    /// can mark the server as auth-expired and prompt re-login.
    private func notifyUnauthorized() {
        var info: [AnyHashable: Any] = [:]
        if let serverId { info["serverId"] = serverId }
        NotificationCenter.default.post(name: .apiClientUnauthorized, object: nil, userInfo: info)
    }

    // MARK: - URL Building

    /// Constructs a URL by appending the given path and optional query parameters to the base URL.
    func buildURL(path: String, query: [URLQueryItem]? = nil) throws -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if let query, !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    /// Builds a fully configured `URLRequest` for the given method, path, query, and optional body.
    func buildRequest<Body: Encodable>(
        method: String,
        path: String,
        query: [URLQueryItem]? = nil,
        body: Body? = nil as String?
    ) throws -> URLRequest {
        let url = try buildURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    /// Builds a `URLRequest` without a request body.
    func buildRequest(
        method: String,
        path: String,
        query: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        try buildRequest(method: method, path: path, query: query, body: nil as String?)
    }

    // MARK: - Core Networking

    /// Executes an HTTP request and decodes the response body into the given type.
    func request<T: Decodable>(
        _: T.Type = T.self,
        method: String,
        path: String,
        query: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
        let url = try buildURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.serverUnreachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverUnreachable
        }

        if httpResponse.statusCode == 401 {
            notifyUnauthorized()
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Executes an HTTP request that does not return a response body.
    func requestVoid(
        method: String,
        path: String,
        query: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws {
        let url = try buildURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.serverUnreachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverUnreachable
        }

        if httpResponse.statusCode == 401 {
            notifyUnauthorized()
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Static Login

    /// Authenticates with the server and returns the login response containing the user's token.
    static func login(serverURL: URL, username: String, password: String) async throws -> LoginResponse {
        guard let components = URLComponents(url: serverURL.appendingPathComponent("/login"), resolvingAgainstBaseURL: false),
              let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.serverUnreachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverUnreachable
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try JSONDecoder().decode(LoginResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Convenience Methods

    /// Fetches all libraries from the server.
    func getLibraries() async throws -> LibrariesResponse {
        try await request(LibrariesResponse.self, method: "GET", path: "/api/libraries")
    }

    /// Fetches a paginated list of items within a library.
    func getLibraryItems(libraryId: String, page: Int = 0, limit: Int = 20) async throws -> LibraryItemsResponse {
        try await request(
            LibraryItemsResponse.self,
            method: "GET",
            path: "/api/libraries/\(libraryId)/items",
            query: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
    }

    /// Fetches full details for a specific library item.
    func getItemDetails(itemId: String) async throws -> LibraryItemResponse {
        try await request(LibraryItemResponse.self, method: "GET", path: "/api/items/\(itemId)")
    }

    /// Searches a library for books, authors, or series matching the given query.
    func searchLibrary(libraryId: String, query: String) async throws -> SearchResponse {
        try await request(
            SearchResponse.self,
            method: "GET",
            path: "/api/libraries/\(libraryId)/search",
            query: [URLQueryItem(name: "q", value: query)]
        )
    }

    /// Starts a new playback session for the specified library item.
    func startPlaybackSession(itemId: String, requestBody: PlaybackSessionRequest) async throws -> PlaybackSessionResponse {
        try await request(
            PlaybackSessionResponse.self,
            method: "POST",
            path: "/api/items/\(itemId)/play",
            body: requestBody
        )
    }

    /// Syncs the current playback position with the server for an active session.
    func syncSession(sessionId: String, body: SessionSyncRequest) async throws {
        try await requestVoid(
            method: "POST",
            path: "/api/session/\(sessionId)/sync",
            body: body
        )
    }

    /// Closes an active playback session on the server.
    func closeSession(sessionId: String) async throws {
        try await requestVoid(
            method: "POST",
            path: "/api/session/\(sessionId)/close"
        )
    }

    /// Fetches the current playback progress for a library item.
    func getProgress(libraryItemId: String) async throws -> MediaProgressResponse {
        try await request(
            MediaProgressResponse.self,
            method: "GET",
            path: "/api/me/progress/\(libraryItemId)"
        )
    }

    /// Updates the playback progress for a library item on the server.
    func updateProgress(libraryItemId: String, progress: ProgressUpdateRequest) async throws {
        try await requestVoid(
            method: "PATCH",
            path: "/api/me/progress/\(libraryItemId)",
            body: progress
        )
    }

    /// Validates the current token and retrieves the authenticated user's information.
    func authorize() async throws -> AuthorizeResponse {
        try await request(AuthorizeResponse.self, method: "POST", path: "/api/authorize")
    }

    /// Fetches the current user's profile including all media progress.
    func getMe() async throws -> UserResponse {
        try await request(UserResponse.self, method: "GET", path: "/api/me")
    }

    /// Hides a series from "Continue Listening" / "Next in Series" on the server.
    func hideSeriesFromContinueListening(seriesId: String) async throws {
        _ = try await request(UserResponse.self, method: "GET", path: "/api/me/series/\(seriesId)/remove-from-continue-listening")
    }

    /// Un-hides a series, restoring it to "Continue Listening" / "Next in Series" on the server.
    func unhideSeriesFromContinueListening(seriesId: String) async throws {
        _ = try await request(UserResponse.self, method: "GET", path: "/api/me/series/\(seriesId)/readd-to-continue-listening")
    }

    // MARK: - Bookmarks

    /// Creates a bookmark on the server for a library item.
    func createBookmark(libraryItemId: String, time: Double, title: String) async throws -> ServerBookmark {
        struct Body: Codable { let time: Double; let title: String }
        return try await request(ServerBookmark.self, method: "POST", path: "/api/me/item/\(libraryItemId)/bookmark", body: Body(time: time, title: title))
    }

    /// Updates an existing bookmark's title on the server.
    func updateBookmark(libraryItemId: String, time: Double, title: String) async throws -> ServerBookmark {
        struct Body: Codable { let time: Double; let title: String }
        return try await request(ServerBookmark.self, method: "PATCH", path: "/api/me/item/\(libraryItemId)/bookmark", body: Body(time: time, title: title))
    }

    /// Deletes a bookmark on the server (identified by libraryItemId + time).
    func deleteBookmark(libraryItemId: String, time: Double) async throws {
        try await requestVoid(method: "DELETE", path: "/api/me/item/\(libraryItemId)/bookmark/\(time)")
    }

    /// Fetches basic series info (name) by ID.
    func getSeriesName(seriesId: String) async throws -> String {
        let data: SeriesBasicResponse = try await request(SeriesBasicResponse.self, method: "GET", path: "/api/series/\(seriesId)")
        return data.name
    }

    /// Fetches listening statistics.
    func getListeningStats() async throws -> ListeningStatsResponse {
        try await request(ListeningStatsResponse.self, method: "GET", path: "/api/me/listening-stats")
    }

    /// Fetches a page of listening sessions for the authenticated user.
    ///
    /// - Parameters:
    ///   - itemId: If non-nil, filters to sessions for this library item.
    ///   - page: Zero-based page index.
    ///   - itemsPerPage: Page size. Defaults to 25.
    func getListeningSessions(
        itemId: String? = nil,
        page: Int = 0,
        itemsPerPage: Int = 25
    ) async throws -> ListeningSessionsPage {
        let query: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "itemsPerPage", value: "\(itemsPerPage)")
        ]
        return try await request(
            ListeningSessionsPage.self,
            method: "GET",
            path: Self.listeningSessionsPath(itemId: itemId),
            query: query
        )
    }

    /// Path for the current user's listening sessions, optionally limited to one library item.
    ///
    /// `/api/me/listening-sessions` doesn't accept an item filter (a `libraryItemId` query is
    /// ignored), so per-item history uses the dedicated route.
    static func listeningSessionsPath(itemId: String?) -> String {
        guard let itemId else { return "/api/me/listening-sessions" }
        return "/api/me/item/listening-sessions/\(itemId)"
    }

    /// Creates or updates a listening session for playback from downloaded files.
    func syncLocalSession(_ session: LocalPlaybackSession) async throws {
        try await requestVoid(
            method: "POST",
            path: "/api/session/local",
            body: session
        )
    }

    // MARK: - URL Builders

    /// Returns a streaming URL for the given content URL path, with the authentication token as a query parameter.
    func streamingURL(contentUrl: String) -> URL? {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(contentUrl), resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        return components.url
    }

    /// Returns a cover image URL for the specified library item, with optional width and the authentication token as query parameters.
    func coverURL(itemId: String, width: Int? = nil) -> URL? {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/items/\(itemId)/cover"),
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }
        var queryItems = [URLQueryItem(name: "token", value: token)]
        if let width {
            queryItems.append(URLQueryItem(name: "width", value: "\(width)"))
        }
        components.queryItems = queryItems
        return components.url
    }
}

// MARK: - AnyEncodable

/// Type-erasing wrapper that allows encoding any `Encodable` value.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
