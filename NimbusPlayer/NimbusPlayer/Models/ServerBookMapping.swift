import Foundation
import SwiftData

// MARK: - ServerBookMapping

/// Links a `CachedBook` to a specific `Server`, storing server-specific metadata
/// such as the library item ID, bitrate, format, and file size.
@Model
final class ServerBookMapping {

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var server: Server?
    var book: CachedBook?
    var libraryItemId: String
    var libraryId: String
    var bitrate: Int?
    var format: String?
    var fileSize: Int64?
    var isPreferred: Bool

    // MARK: - Init

    init(
        server: Server,
        book: CachedBook,
        libraryItemId: String,
        libraryId: String,
        bitrate: Int? = nil,
        format: String? = nil,
        fileSize: Int64? = nil,
        isPreferred: Bool = false
    ) {
        self.id = UUID()
        self.server = server
        self.book = book
        self.libraryItemId = libraryItemId
        self.libraryId = libraryId
        self.bitrate = bitrate
        self.format = format
        self.fileSize = fileSize
        self.isPreferred = isPreferred
    }
}
