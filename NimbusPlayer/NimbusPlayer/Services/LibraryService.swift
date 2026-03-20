import Foundation
import SwiftData

// MARK: - MergedBook

/// Represents a deduplicated book that may exist on multiple servers.
struct MergedBook {
    let identity: BookMatcher.BookIdentity
    var serverItems: [(server: Server, item: LibraryItemResponse, libraryId: String)]
}

// MARK: - LibraryService

/// Fetches audiobooks from all configured servers, deduplicates them, and persists
/// the merged results into SwiftData.
@Observable
final class LibraryService {

    // MARK: - Properties

    private(set) var isLoading = false
    private(set) var lastError: String?

    // MARK: - Public API

    /// Refreshes the local library by fetching items from every active server,
    /// deduplicating across servers, and upserting the results into SwiftData.
    ///
    /// - Parameters:
    ///   - servers: The list of active servers to fetch from.
    ///   - serverService: A closure that builds an `APIClient` for a given server.
    ///   - modelContext: The SwiftData model context for persistence.
    @MainActor
    func refreshLibrary(
        servers: [Server],
        serverService: (Server) -> APIClient?,
        modelContext: ModelContext
    ) async {
        isLoading = true
        lastError = nil

        // Fetch from network (runs off main actor automatically for async calls)
        var serverItems: [(Server, [LibraryItemResponse])] = []
        for server in servers {
            guard let client = serverService(server) else { continue }
            do {
                let items = try await fetchAllItems(client: client)
                serverItems.append((server, items))
            } catch {
                lastError = "Failed to fetch from \(server.displayName): \(error.localizedDescription)"
            }
        }

        // Dedup and persist on main actor (safe for SwiftData + @Observable)
        let mergedBooks = deduplicateItems(serverItems)
        persistBooks(mergedBooks, modelContext: modelContext)

        isLoading = false
    }

    // MARK: - Fetch All Items

    /// Fetches ALL library items from all book libraries on a server using pagination.
    ///
    /// Each library is paginated independently (page counter resets per library).
    /// Only libraries with `mediaType == "book"` are included.
    private func fetchAllItems(client: APIClient) async throws -> [LibraryItemResponse] {
        let librariesResponse = try await client.getLibraries()
        let bookLibraries = librariesResponse.libraries.filter { $0.mediaType == "book" }

        var allItems: [LibraryItemResponse] = []

        for library in bookLibraries {
            var page = 0
            let limit = 100

            while true {
                let response = try await client.getLibraryItems(
                    libraryId: library.id,
                    page: page,
                    limit: limit
                )
                allItems.append(contentsOf: response.results)

                // Per-library counter: check fetched count against this library's total
                let fetchedCount = (page + 1) * limit
                if fetchedCount >= response.total {
                    break
                }
                page += 1
            }
        }

        return allItems
    }

    // MARK: - Deduplication

    /// Groups items from multiple servers into merged books using `BookMatcher.areMatching`.
    ///
    /// Items that match across servers are collapsed into a single `MergedBook`.
    private func deduplicateItems(_ serverItems: [(Server, [LibraryItemResponse])]) -> [MergedBook] {
        var mergedBooks: [MergedBook] = []

        for (server, items) in serverItems {
            for item in items {
                let identity = BookMatcher.BookIdentity(
                    asin: item.asin,
                    isbn: item.isbn,
                    title: item.title ?? "",
                    author: item.authorName ?? ""
                )

                // Only merge with an existing entry if it came from a DIFFERENT server.
                // Two items on the same server are always distinct books.
                if let index = mergedBooks.firstIndex(where: {
                    BookMatcher.areMatching($0.identity, identity)
                    && !$0.serverItems.contains(where: { $0.server.id == server.id })
                }) {
                    mergedBooks[index].serverItems.append(
                        (server: server, item: item, libraryId: item.libraryId)
                    )
                } else {
                    mergedBooks.append(MergedBook(
                        identity: identity,
                        serverItems: [(server: server, item: item, libraryId: item.libraryId)]
                    ))
                }
            }
        }

        return mergedBooks
    }

    // MARK: - Persistence

    /// Upserts `CachedBook` and `ServerBookMapping` records into SwiftData.
    ///
    /// Existing books (matched by deterministic UUID) are updated in place;
    /// new books are inserted. Server mappings are reconciled so stale entries
    /// are removed and new ones added.
    private func persistBooks(_ mergedBooks: [MergedBook], modelContext: ModelContext) {
        for merged in mergedBooks {
            let identity = merged.identity
            let bookId = UUIDv5.bookID(
                asin: identity.asin,
                isbn: identity.isbn,
                title: identity.title,
                author: identity.author
            )

            // Try to fetch existing book
            let descriptor = FetchDescriptor<CachedBook>(
                predicate: #Predicate { $0.id == bookId }
            )
            let existingBook = (try? modelContext.fetch(descriptor))?.first

            let book: CachedBook
            if let existingBook {
                // Update existing book metadata from the first server item
                let primaryItem = merged.serverItems[0].item
                existingBook.title = primaryItem.title ?? existingBook.title
                existingBook.author = primaryItem.authorName ?? existingBook.author
                existingBook.narrator = primaryItem.narratorName ?? existingBook.narrator
                existingBook.asin = primaryItem.asin ?? existingBook.asin
                existingBook.isbn = primaryItem.isbn ?? existingBook.isbn
                existingBook.bookDescription = primaryItem.media.metadata.description ?? existingBook.bookDescription
                existingBook.duration = primaryItem.media.duration ?? primaryItem.totalDuration ?? existingBook.duration
                existingBook.coverPath = primaryItem.media.coverPath ?? existingBook.coverPath
                existingBook.seriesName = primaryItem.seriesName ?? existingBook.seriesName
                existingBook.seriesSequence = primaryItem.seriesSequence ?? existingBook.seriesSequence
                if let genres = primaryItem.media.metadata.genres, !genres.isEmpty {
                    existingBook.genres = genres
                }
                existingBook.lastUpdated = Date()
                book = existingBook
            } else {
                let primaryItem = merged.serverItems[0].item
                let newBook = CachedBook(
                    title: primaryItem.title ?? "Unknown Title",
                    author: primaryItem.authorName ?? "Unknown Author",
                    duration: primaryItem.media.duration ?? primaryItem.totalDuration ?? 0,
                    asin: primaryItem.asin,
                    isbn: primaryItem.isbn,
                    narrator: primaryItem.narratorName,
                    bookDescription: primaryItem.media.metadata.description,
                    coverPath: primaryItem.media.coverPath,
                    seriesName: primaryItem.seriesName,
                    seriesSequence: primaryItem.seriesSequence
                )
                newBook.genres = primaryItem.media.metadata.genres ?? []
                modelContext.insert(newBook)
                book = newBook
            }

            // Reconcile server mappings — use libraryItemId alone to avoid
            // SwiftData lazy-loading issues with the server relationship
            let hadMappings = !book.serverMappings.isEmpty
            for (index, serverItem) in merged.serverItems.enumerated() {
                let server = serverItem.server
                let item = serverItem.item
                let libraryId = serverItem.libraryId

                let existingMapping = book.serverMappings.first {
                    $0.libraryItemId == item.id
                }

                if let mapping = existingMapping {
                    // Update existing mapping
                    mapping.libraryId = libraryId
                    mapping.bitrate = item.totalBitrate.map { Int($0) }
                    mapping.format = item.audioFormat
                    mapping.fileSize = item.totalSize
                } else {
                    // Create new mapping
                    let mapping = ServerBookMapping(
                        server: server,
                        book: book,
                        libraryItemId: item.id,
                        libraryId: libraryId,
                        bitrate: item.totalBitrate.map { Int($0) },
                        format: item.audioFormat,
                        fileSize: item.totalSize,
                        isPreferred: index == 0 && !hadMappings
                    )
                    modelContext.insert(mapping)
                }
            }
        }

        try? modelContext.save()
    }
}
