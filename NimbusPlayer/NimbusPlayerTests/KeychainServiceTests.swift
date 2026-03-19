import Testing
import Foundation
@testable import NimbusPlayer

@Suite("KeychainService Tests")
struct KeychainServiceTests {
    private let service = KeychainService()

    @Test func saveAndRetrieveToken() throws {
        let serverId = UUID()
        let token = "test-token-\(UUID().uuidString)"

        try service.saveToken(token, for: serverId)
        let retrieved = try service.getToken(for: serverId)
        #expect(retrieved == token)

        // Cleanup
        try service.deleteToken(for: serverId)
    }

    @Test func deleteToken() throws {
        let serverId = UUID()
        let token = "delete-me-\(UUID().uuidString)"

        try service.saveToken(token, for: serverId)
        try service.deleteToken(for: serverId)

        let retrieved = try service.getToken(for: serverId)
        #expect(retrieved == nil)
    }

    @Test func updateExistingToken() throws {
        let serverId = UUID()
        let oldToken = "old-token-\(UUID().uuidString)"
        let newToken = "new-token-\(UUID().uuidString)"

        try service.saveToken(oldToken, for: serverId)
        try service.saveToken(newToken, for: serverId)

        let retrieved = try service.getToken(for: serverId)
        #expect(retrieved == newToken)

        // Cleanup
        try service.deleteToken(for: serverId)
    }

    @Test func getMissingTokenReturnsNil() throws {
        let randomId = UUID()
        let retrieved = try service.getToken(for: randomId)
        #expect(retrieved == nil)
    }
}
