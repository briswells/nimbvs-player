import Foundation
import SwiftData

// MARK: - ListeningProgress

/// Tracks the user's listening position and playback state for a book.
///
/// The current chapter is derived from the playback time at runtime rather
/// than being persisted, keeping this model lean and avoiding stale data.
@Model
final class ListeningProgress {

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var book: CachedBook?
    var currentTime: TimeInterval
    var totalDuration: TimeInterval
    var progress: Double
    var isFinished: Bool

    /// Per-book playback speed override. `nil` means use the global default.
    var playbackSpeed: Double?

    var lastUpdated: Date
    var needsSync: Bool

    /// The active Audiobookshelf playback session ID, if any.
    var activeSessionId: String?

    /// The server UUID associated with the active session.
    var activeSessionServerId: UUID?

    // MARK: - Init

    init(
        book: CachedBook,
        currentTime: TimeInterval = 0,
        totalDuration: TimeInterval = 0
    ) {
        self.id = UUID()
        self.book = book
        self.currentTime = currentTime
        self.totalDuration = totalDuration
        self.progress = totalDuration > 0 ? currentTime / totalDuration : 0
        self.isFinished = false
        self.playbackSpeed = nil
        self.lastUpdated = Date()
        self.needsSync = false
        self.activeSessionId = nil
        self.activeSessionServerId = nil
    }

    // MARK: - Methods

    /// Updates the listening position and recalculates progress.
    ///
    /// - Parameters:
    ///   - currentTime: The new playback position in seconds.
    ///   - duration: The total duration of the book in seconds.
    func update(currentTime: TimeInterval, duration: TimeInterval, completionThreshold: Double = 1.0) {
        self.currentTime = currentTime
        self.totalDuration = duration
        self.progress = duration > 0 ? currentTime / duration : 0
        self.isFinished = duration > 0 && progress >= completionThreshold
        self.lastUpdated = Date()
        self.needsSync = true
    }
}
