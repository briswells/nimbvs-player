import Foundation

struct ListeningStatsResponse: Codable {
    let totalTime: Double
    let items: [String: ListeningStatsItem]?
    let days: [String: Double]?
    let dayOfWeek: [String: Double]?
    let today: Double?
    let recentSessions: [RecentSession]?
}

struct ListeningStatsItem: Codable {
    let id: String
    let timeListening: Double
    let mediaMetadata: StatsMediaMetadata?
}

struct StatsMediaMetadata: Codable {
    let title: String?
    let authors: [AuthorResponse]?
}

struct RecentSession: Codable {
    let id: String
    let date: String?
    let dayOfWeek: String?
    let timeListening: Double
    let mediaMetadata: StatsMediaMetadata?
}
