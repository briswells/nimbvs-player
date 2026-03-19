import Foundation

// MARK: - ServerService

/// Manages API client connections and authentication state for all configured servers.
@Observable
final class ServerService {

    // MARK: - ServerStatus

    /// Describes the current connectivity/authentication state of a server.
    enum ServerStatus: Equatable {
        case connected
        case unreachable
        case authExpired
        case unknown
    }

    // MARK: - Properties

    private let keychain = KeychainService()

    /// Active API clients keyed by server ID.
    private(set) var clients: [UUID: APIClient] = [:]

    /// Current status of each server keyed by server ID.
    private(set) var serverStatuses: [UUID: ServerStatus] = [:]

    // MARK: - Client Access

    /// Returns the API client for the given server, if one has been registered.
    func client(for serverId: UUID) -> APIClient? {
        clients[serverId]
    }

    // MARK: - Loading

    /// Initialises API clients for each server by retrieving stored tokens from the Keychain.
    ///
    /// Servers without a stored token are marked as `authExpired`.
    func loadClients(servers: [Server]) {
        for server in servers {
            guard let baseURL = server.baseURL else {
                serverStatuses[server.id] = .unreachable
                continue
            }

            do {
                if let token = try keychain.getToken(for: server.id) {
                    let client = APIClient(baseURL: baseURL, token: token)
                    clients[server.id] = client
                    serverStatuses[server.id] = .unknown
                } else {
                    serverStatuses[server.id] = .authExpired
                }
            } catch {
                serverStatuses[server.id] = .authExpired
            }
        }
    }

    // MARK: - Authentication

    /// Logs in to the server at the given URL and returns the authentication token and user ID.
    func login(url: URL, username: String, password: String) async throws -> (token: String, userId: String) {
        let response = try await APIClient.login(serverURL: url, username: username, password: password)
        return (token: response.user.token, userId: response.user.id)
    }

    /// Registers a server by persisting its token in the Keychain and creating an API client.
    func registerServer(_ server: Server, token: String) throws {
        try keychain.saveToken(token, for: server.id)

        guard let baseURL = server.baseURL else {
            throw APIError.invalidURL
        }

        let client = APIClient(baseURL: baseURL, token: token)
        clients[server.id] = client
        serverStatuses[server.id] = .connected
    }

    // MARK: - Validation

    /// Checks authentication status for all servers in parallel and updates `serverStatuses`.
    func validateConnections(servers: [Server]) async {
        await withTaskGroup(of: (UUID, ServerStatus).self) { group in
            for server in servers {
                guard let client = clients[server.id] else {
                    serverStatuses[server.id] = .authExpired
                    continue
                }

                group.addTask {
                    do {
                        _ = try await client.authorize()
                        return (server.id, .connected)
                    } catch let error as APIError {
                        switch error {
                        case .unauthorized:
                            return (server.id, .authExpired)
                        case .serverUnreachable:
                            return (server.id, .unreachable)
                        default:
                            return (server.id, .unreachable)
                        }
                    } catch {
                        return (server.id, .unreachable)
                    }
                }
            }

            for await (serverId, status) in group {
                serverStatuses[serverId] = status
            }
        }
    }

    // MARK: - Removal

    /// Deletes the stored token and removes the API client for the given server.
    func removeServer(_ server: Server) {
        try? keychain.deleteToken(for: server.id)
        clients.removeValue(forKey: server.id)
        serverStatuses.removeValue(forKey: server.id)
    }
}
