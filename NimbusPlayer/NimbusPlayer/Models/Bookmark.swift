import Foundation
import SwiftData

// MARK: - Bookmark

/// A user-created bookmark at a specific timestamp within a book.
@Model
final class Bookmark {

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var book: CachedBook?
    var timestamp: TimeInterval
    var note: String?
    var dateCreated: Date

    // MARK: - Init

    init(
        book: CachedBook,
        timestamp: TimeInterval,
        note: String? = nil
    ) {
        self.id = UUID()
        self.book = book
        self.timestamp = timestamp
        self.note = note
        self.dateCreated = Date()
    }
}
