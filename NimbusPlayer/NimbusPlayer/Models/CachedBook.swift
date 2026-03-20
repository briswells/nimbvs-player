import Foundation
import SwiftData

// MARK: - CachedBook

/// A locally cached audiobook that may exist on one or more servers.
///
/// The book's `id` is deterministic via `UUIDv5.bookID`, ensuring the same
/// book from different servers resolves to a single `CachedBook` record.
@Model
final class CachedBook {

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var narrator: String?
    var asin: String?
    var isbn: String?
    var bookDescription: String?
    var duration: TimeInterval
    var coverPath: String?
    var seriesName: String?
    var seriesSequence: String?
    var genres: [String] = []
    var lastUpdated: Date

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \ServerBookMapping.book)
    var serverMappings: [ServerBookMapping] = []

    @Relationship(deleteRule: .cascade)
    var progress: ListeningProgress?

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.book)
    var bookmarks: [Bookmark] = []

    @Relationship(deleteRule: .cascade, inverse: \DownloadModel.book)
    var downloads: [DownloadModel] = []

    // MARK: - Init

    init(
        title: String,
        author: String,
        duration: TimeInterval,
        asin: String? = nil,
        isbn: String? = nil,
        narrator: String? = nil,
        bookDescription: String? = nil,
        coverPath: String? = nil,
        seriesName: String? = nil,
        seriesSequence: String? = nil
    ) {
        self.id = UUIDv5.bookID(asin: asin, isbn: isbn, title: title, author: author)
        self.title = title
        self.author = author
        self.narrator = narrator
        self.asin = asin
        self.isbn = isbn
        self.bookDescription = bookDescription
        self.duration = duration
        self.coverPath = coverPath
        self.seriesName = seriesName
        self.seriesSequence = seriesSequence
        self.lastUpdated = Date()
    }

    // MARK: - Computed

    /// The preferred server mapping, or the first available mapping if none is marked preferred.
    var preferredMapping: ServerBookMapping? {
        serverMappings.first(where: { $0.isPreferred }) ?? serverMappings.first
    }

    /// Whether this book is available on more than one server.
    var isMultiServer: Bool {
        serverMappings.count > 1
    }
}
