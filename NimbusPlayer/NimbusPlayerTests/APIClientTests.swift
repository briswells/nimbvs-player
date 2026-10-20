import Testing
import Foundation
@testable import NimbusPlayer

@Suite("APIClient Tests")
struct APIClientTests {

    private let baseURL = URL(string: "https://abs.example.com")!
    private let token = "test-token-abc123"

    private var client: APIClient {
        APIClient(baseURL: baseURL, token: token)
    }

    // MARK: - buildURL Tests

    @Test func buildURLAppendsPath() throws {
        let url = try client.buildURL(path: "/api/libraries")
        #expect(url.absoluteString == "https://abs.example.com/api/libraries")
    }

    @Test func buildURLWithQueryParams() throws {
        let url = try client.buildURL(
            path: "/api/libraries/lib1/items",
            query: [
                URLQueryItem(name: "page", value: "0"),
                URLQueryItem(name: "limit", value: "20")
            ]
        )
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(components.path == "/api/libraries/lib1/items")

        let queryItems = components.queryItems ?? []
        #expect(queryItems.contains(URLQueryItem(name: "page", value: "0")))
        #expect(queryItems.contains(URLQueryItem(name: "limit", value: "20")))
    }

    // MARK: - buildRequest Tests

    @Test func buildRequestIncludesAuthHeader() throws {
        let request = try client.buildRequest(method: "GET", path: "/api/libraries")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token-abc123")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 15)
    }

    // MARK: - getListeningSessions URL tests

    @Test func listeningSessionsURLNoFilter() throws {
        let url = try client.buildURL(
            path: "/api/me/listening-sessions",
            query: [
                URLQueryItem(name: "page", value: "0"),
                URLQueryItem(name: "itemsPerPage", value: "25")
            ]
        )
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(components.path == "/api/me/listening-sessions")
        let items = components.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "page", value: "0")))
        #expect(items.contains(URLQueryItem(name: "itemsPerPage", value: "25")))
        #expect(!items.contains(where: { $0.name == "libraryItemId" }))
    }


    @Test func listeningSessionsPathAllBooks() {
        #expect(APIClient.listeningSessionsPath(itemId: nil) == "/api/me/listening-sessions")
    }

    /// Audiobookshelf ignores a `libraryItemId` query on `/api/me/listening-sessions`; per-item
    /// history has its own route.
    @Test func listeningSessionsPathForItem() {
        #expect(APIClient.listeningSessionsPath(itemId: "item-abc") == "/api/me/item/listening-sessions/item-abc")
    }

    // MARK: - Local (offline) sessions

    @Test func localSessionEncodesAsLocalPlayback() throws {
        let session = LocalPlaybackSession(
            libraryItemId: "item-abc",
            displayTitle: "Title",
            displayAuthor: "Author",
            duration: 3600,
            startTime: 100,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            deviceInfo: PlaybackSessionRequest.defaultRequest(deviceId: "dev", appVersion: "1.0").deviceInfo
        )
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as! [String: Any]
        #expect(json["libraryItemId"] as? String == "item-abc")
        #expect(json["mediaType"] as? String == "book")
        #expect(json["playMethod"] as? Int == 3)
        #expect(json["startTime"] as? Double == 100)
        #expect(json["currentTime"] as? Double == 100)
        #expect(json["timeListening"] as? Double == 0)
        #expect(json["startedAt"] as? Int64 == 1_700_000_000_000)
        #expect(json["updatedAt"] as? Int64 == 1_700_000_000_000)
        #expect((json["id"] as? String)?.isEmpty == false)
    }

    @Test func localSessionAccumulatesListeningTime() {
        var session = LocalPlaybackSession(
            libraryItemId: "item-abc", displayTitle: "T", displayAuthor: "A", duration: 3600,
            startTime: 0, startedAt: Date(timeIntervalSince1970: 0),
            deviceInfo: PlaybackSessionRequest.defaultRequest(deviceId: "dev", appVersion: "1.0").deviceInfo
        )
        session.recordListening(seconds: 5, currentTime: 5, at: Date(timeIntervalSince1970: 5))
        session.recordListening(seconds: 5, currentTime: 10, at: Date(timeIntervalSince1970: 10))
        #expect(session.timeListening == 10)
        #expect(session.currentTime == 10)
        #expect(session.updatedAt == 10_000)
    }

    /// A long gap between ticks (app suspended, timer stalled) must not count as listening time.
    @Test func localSessionCapsLongGaps() {
        var session = LocalPlaybackSession(
            libraryItemId: "item-abc", displayTitle: "T", displayAuthor: "A", duration: 3600,
            startTime: 0, startedAt: Date(timeIntervalSince1970: 0),
            deviceInfo: PlaybackSessionRequest.defaultRequest(deviceId: "dev", appVersion: "1.0").deviceInfo
        )
        session.recordListening(seconds: 600, currentTime: 20, at: Date(timeIntervalSince1970: 600))
        session.recordListening(seconds: -3, currentTime: 20, at: Date(timeIntervalSince1970: 601))
        #expect(session.timeListening == LocalPlaybackSession.maxTickSeconds)
    }

    /// Removing an uploaded session must not drop time recorded after the upload started.
    @Test func localSessionStoreKeepsNewerCopyOnRemove() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PendingLocalSessions-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = LocalSessionStore(fileURL: url)

        var pending = PendingLocalSession(
            serverId: UUID(),
            bookId: UUID(),
            session: LocalPlaybackSession(
                libraryItemId: "item-abc", displayTitle: "T", displayAuthor: "A", duration: 3600,
                startTime: 0, startedAt: Date(timeIntervalSince1970: 0),
                deviceInfo: PlaybackSessionRequest.defaultRequest(deviceId: "dev", appVersion: "1.0").deviceInfo
            )
        )
        pending.session.recordListening(seconds: 5, currentTime: 5, at: Date(timeIntervalSince1970: 5))
        store.upsert(pending)
        let uploaded = pending

        pending.session.recordListening(seconds: 5, currentTime: 10, at: Date(timeIntervalSince1970: 10))
        store.upsert(pending)
        #expect(store.load().count == 1)

        store.remove(uploaded)
        #expect(store.load() == [pending])

        store.remove(pending)
        #expect(store.load().isEmpty)
    }
}
