import Foundation
import SwiftData

// MARK: - Server

/// Represents an Audiobookshelf server connection.
///
/// Each server stores its URL, credentials, and active state.
/// A server owns its book mappings and downloads via cascade delete rules.
@Model
final class Server {

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var url: String
    var username: String
    var displayName: String
    var isActive: Bool
    var lastConnected: Date?

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \ServerBookMapping.server)
    var bookMappings: [ServerBookMapping] = []

    @Relationship(deleteRule: .cascade, inverse: \DownloadModel.server)
    var downloads: [DownloadModel] = []

    // MARK: - Init

    init(url: String, username: String, displayName: String) {
        self.id = UUID()
        // Strip trailing slash for consistent URL handling
        self.url = url.hasSuffix("/") ? String(url.dropLast()) : url
        self.username = username
        self.displayName = displayName
        self.isActive = true
        self.lastConnected = nil
    }

    // MARK: - Computed

    /// The server URL parsed as a `URL`, or `nil` if the string is invalid.
    var baseURL: URL? {
        URL(string: url)
    }
}
