import Foundation

/// Paginated response from `/api/me/listening-sessions`.
struct ListeningSessionsPage: Codable {
    let total: Int
    let numPages: Int
    let page: Int
    let itemsPerPage: Int
    let sessions: [ListeningSessionResponse]
}

/// A single listening session as returned by Audiobookshelf.
///
/// Timestamps are milliseconds since epoch. Positions (`startTime`, `currentTime`, `duration`)
/// are in seconds within the book. `timeListening` is wall-clock seconds actually listened.
struct ListeningSessionResponse: Codable, Identifiable {
    let id: String
    let libraryItemId: String?
    let displayTitle: String?
    let displayAuthor: String?
    let mediaMetadata: StatsMediaMetadata?
    let playMethod: Int?
    let startedAt: Double
    let updatedAt: Double
    let startTime: Double
    let currentTime: Double
    let duration: Double?
    let timeListening: Double
    let deviceInfo: DeviceInfo?

    struct DeviceInfo: Codable {
        let deviceName: String?
        let browserName: String?
        let osName: String?
        let clientName: String?
    }
}
