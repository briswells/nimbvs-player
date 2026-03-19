import Foundation

// MARK: - LibraryItemsResponse

/// Paginated list of library items returned by the API.
struct LibraryItemsResponse: Codable {
    let results: [LibraryItemResponse]
    let total: Int
    let limit: Int
    let page: Int
}

// MARK: - LibraryItemResponse

/// A single library item (audiobook or podcast) from the Audiobookshelf API.
struct LibraryItemResponse: Codable {
    let id: String
    let ino: String?
    let libraryId: String
    let mediaType: String
    let media: MediaResponse

    // MARK: - Convenience Properties

    /// The book or podcast title.
    var title: String? {
        media.metadata.title
    }

    /// The primary author name.
    var authorName: String? {
        media.metadata.authorName
    }

    /// The narrator name.
    var narratorName: String? {
        media.metadata.narratorName
    }

    /// Amazon Standard Identification Number.
    var asin: String? {
        media.metadata.asin
    }

    /// International Standard Book Number.
    var isbn: String? {
        media.metadata.isbn
    }

    /// Series name — from structured series array, or parsed from the pre-computed seriesName string.
    var seriesName: String? {
        if let name = media.metadata.series?.first?.name, !name.isEmpty {
            return name
        }
        // Fall back to parsing "The Expanse #3" → "The Expanse"
        guard let raw = media.metadata.seriesName, !raw.isEmpty else { return nil }
        let parts = raw.split(separator: "#", maxSplits: 1)
        return parts.first.map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    /// Series sequence — from structured series array, or parsed from the pre-computed seriesName string.
    var seriesSequence: String? {
        if let seq = media.metadata.series?.first?.sequence, !seq.isEmpty {
            return seq
        }
        // Fall back to parsing "The Expanse #3" → "3"
        guard let raw = media.metadata.seriesName, !raw.isEmpty else { return nil }
        let parts = raw.split(separator: "#", maxSplits: 1)
        guard parts.count > 1 else { return nil }
        let seq = String(parts[1]).trimmingCharacters(in: .whitespaces)
        return seq.isEmpty ? nil : seq
    }

    /// Total duration of all audio files in seconds.
    var totalDuration: Double? {
        media.audioFiles?.reduce(0.0) { $0 + $1.duration }
    }

    /// Total bitrate across all audio files.
    var totalBitrate: Double? {
        guard let files = media.audioFiles, !files.isEmpty else { return nil }
        return files.compactMap(\.bitRate).reduce(0.0, +) / Double(files.count)
    }

    /// Total size in bytes of all audio files.
    var totalSize: Int64? {
        media.audioFiles?.compactMap(\.metadata?.size).reduce(0, +)
    }

    /// The audio format of the first audio file, if available.
    var audioFormat: String? {
        media.audioFiles?.first?.mimeType
    }
}

// MARK: - MediaResponse

/// The media payload within a library item (contains metadata, audio files, chapters).
struct MediaResponse: Codable {
    let metadata: MetadataResponse
    let audioFiles: [AudioFileResponse]?
    let chapters: [ChapterResponse]?
    let coverPath: String?
    let duration: Double?
}

// MARK: - MetadataResponse

/// Metadata describing a book or podcast.
struct MetadataResponse: Codable {
    let title: String?
    let subtitle: String?
    let authorName: String?
    let narratorName: String?
    let description: String?
    let isbn: String?
    let asin: String?
    let language: String?
    let publishedYear: String?
    let publisher: String?
    let genres: [String]?
    let authors: [AuthorResponse]?
    let series: [SeriesEntryResponse]?
    /// Pre-computed by the server, e.g. "The Expanse #3" or "Harry Potter (Full-Cast Editions) #2"
    let seriesName: String?
}

// MARK: - AuthorResponse

/// An author referenced in metadata.
struct AuthorResponse: Codable {
    let id: String
    let name: String
}

// MARK: - SeriesEntryResponse

/// A series entry associating a library item with a named series and optional sequence.
struct SeriesEntryResponse: Codable {
    let id: String
    let name: String
    let sequence: String?
}

// MARK: - AudioFileResponse

/// A single audio file within a library item.
struct AudioFileResponse: Codable {
    let index: Int
    let ino: String?
    let duration: Double
    let mimeType: String
    let bitRate: Double?
    let codec: String?
    let metadata: FileMetadataResponse?
}

// MARK: - FileMetadataResponse

/// File-system metadata for an audio file.
struct FileMetadataResponse: Codable {
    let filename: String?
    let ext: String?
    let path: String?
    let size: Int64?
}

// MARK: - ChapterResponse

/// A chapter marker with start/end offsets and a title.
struct ChapterResponse: Codable {
    let id: Int
    let start: Double
    let end: Double
    let title: String
}
