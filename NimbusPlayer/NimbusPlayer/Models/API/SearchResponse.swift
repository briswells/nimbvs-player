import Foundation

// MARK: - SearchResponse

/// Response returned by the library search endpoint.
struct SearchResponse: Codable {
    let book: [SearchBookResult]?
    let authors: [SearchAuthorResult]?
    let series: [SearchSeriesResult]?
}

// MARK: - SearchBookResult

/// A single book result from a search query.
struct SearchBookResult: Codable {
    let libraryItem: LibraryItemResponse
    let matchKey: String?
    let matchText: String?
}

// MARK: - SearchAuthorResult

/// A single author result from a search query.
struct SearchAuthorResult: Codable {
    let id: String
    let name: String
}

// MARK: - SearchSeriesResult

/// A single series result from a search query.
struct SearchSeriesResult: Codable {
    let series: SearchSeriesInfo
    let books: [LibraryItemResponse]
}

// MARK: - SearchSeriesInfo

/// Metadata about a series returned in search results.
struct SearchSeriesInfo: Codable {
    let id: String
    let name: String
}
