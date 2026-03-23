import Foundation

// MARK: - LoginResponse

/// Response returned by the `/login` endpoint.
struct LoginResponse: Codable {
    let user: UserResponse
}

// MARK: - UserResponse

/// Represents the authenticated user in API responses.
struct UserResponse: Codable {
    let id: String
    let username: String
    let type: String
    let token: String
    let mediaProgress: [MediaProgressResponse]?
    let seriesHideFromContinueListening: [String]?
    let bookmarks: [ServerBookmark]?
}

// MARK: - MediaProgressResponse

/// Tracks a user's playback progress for a specific library item or episode.
struct MediaProgressResponse: Codable {
    let id: String
    let libraryItemId: String
    let episodeId: String?
    let duration: Double
    let progress: Double
    let currentTime: Double
    let isFinished: Bool
    let lastUpdate: TimeInterval
    let startedAt: TimeInterval?
    let finishedAt: TimeInterval?
}

// MARK: - ServerBookmark

/// A bookmark as returned by the Audiobookshelf API.
struct ServerBookmark: Codable {
    let libraryItemId: String
    let time: Double
    let title: String
    let createdAt: TimeInterval
}

// MARK: - SeriesBasicResponse

/// Minimal response from the series detail endpoint.
struct SeriesBasicResponse: Codable {
    let id: String
    let name: String
}

// MARK: - AuthorizeResponse

/// Response returned by the `/authorize` endpoint (same shape minus login-specific fields).
struct AuthorizeResponse: Codable {
    let user: UserResponse
}
