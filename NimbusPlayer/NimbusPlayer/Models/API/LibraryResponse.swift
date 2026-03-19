import Foundation

// MARK: - LibrariesResponse

/// Wrapper for the `/libraries` endpoint which returns an array of libraries.
struct LibrariesResponse: Codable {
    let libraries: [LibraryResponse]
}

// MARK: - LibraryResponse

/// A single Audiobookshelf library.
struct LibraryResponse: Codable {
    let id: String
    let name: String
    let mediaType: String
    let folders: [FolderResponse]?
}

// MARK: - FolderResponse

/// A folder within a library.
struct FolderResponse: Codable {
    let id: String
    let fullPath: String
}
