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
}
