import Foundation
import SwiftData

// MARK: - DownloadState

/// The lifecycle states of a book download.
enum DownloadState: String, Codable {
    case queued
    case downloading
    case paused
    case complete
    case failed
}

// MARK: - DownloadModel

/// Tracks the download state and progress for a book's audio files.
///
/// File paths are stored as relative paths to maintain compatibility with
/// iOS sandbox directory changes between app launches.
@Model
final class DownloadModel {

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var book: CachedBook?
    var server: Server?
    var state: DownloadState
    var totalBytes: Int64
    var downloadedBytes: Int64

    /// Relative file paths within the app's documents directory.
    var relativeFilePaths: [String]

    var dateStarted: Date
    var dateCompleted: Date?
    var errorMessage: String?

    // MARK: - Init

    init(
        book: CachedBook,
        server: Server
    ) {
        self.id = UUID()
        self.book = book
        self.server = server
        self.state = .queued
        self.totalBytes = 0
        self.downloadedBytes = 0
        self.relativeFilePaths = []
        self.dateStarted = Date()
        self.dateCompleted = nil
        self.errorMessage = nil
    }

    // MARK: - Computed

    /// The download progress as a fraction from 0.0 to 1.0.
    var progressFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }
}
