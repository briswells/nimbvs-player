import Foundation
import SwiftData

// MARK: - PendingSyncAction

/// A queued server-bound operation that will be retried until successful.
@Model
final class PendingSyncAction {

    @Attribute(.unique) var id: UUID
    var actionType: String
    var payload: Data
    var serverId: UUID
    var createdAt: Date

    init(actionType: String, payload: Data, serverId: UUID) {
        self.id = UUID()
        self.actionType = actionType
        self.payload = payload
        self.serverId = serverId
        self.createdAt = Date()
    }
}

// MARK: - Action Types

enum SyncActionType: String {
    case bookmarkCreate
    case bookmarkDelete
    case seriesHide
    case markComplete
}

// MARK: - Payloads

struct BookmarkCreatePayload: Codable {
    let libraryItemId: String
    let time: Double
    let title: String
}

struct BookmarkDeletePayload: Codable {
    let libraryItemId: String
    let time: Double
}

struct SeriesHidePayload: Codable {
    let seriesId: String
}

struct MarkCompletePayload: Codable {
    let libraryItemId: String
    let progress: Double
    let currentTime: Double
    let duration: Double
}
