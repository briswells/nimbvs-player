import Foundation
import SwiftData

// MARK: - LibraryViewModel

/// View model that manages library display state including sorting, layout, and refresh.
@Observable
final class LibraryViewModel {

    // MARK: - Sort Option

    enum SortOption: String, CaseIterable {
        case recentlyAdded
        case title
        case author
        case duration

        var displayName: String {
            switch self {
            case .recentlyAdded: "Recently Added"
            case .title: "Title"
            case .author: "Author"
            case .duration: "Duration"
            }
        }
    }

    // MARK: - Properties

    var isGridView = true
    var sortOption: SortOption = .recentlyAdded
    var isRefreshing = false

    private let libraryService: LibraryService

    // MARK: - Init

    init(libraryService: LibraryService = LibraryService()) {
        self.libraryService = libraryService
    }

    // MARK: - Refresh

    /// Triggers a full library refresh from all servers.
    ///
    /// - Parameters:
    ///   - servers: Active servers to fetch from.
    ///   - serverService: Closure that creates an `APIClient` for a server.
    ///   - modelContext: The SwiftData model context for persistence.
    func refresh(
        servers: [Server],
        serverService: (Server) -> APIClient?,
        modelContext: ModelContext
    ) async {
        isRefreshing = true
        await libraryService.refreshLibrary(
            servers: servers,
            serverService: serverService,
            modelContext: modelContext
        )
        isRefreshing = false
    }

    // MARK: - Sorting

    /// Returns the books sorted according to the current `sortOption`.
    func sortedBooks(_ books: [CachedBook]) -> [CachedBook] {
        switch sortOption {
        case .recentlyAdded:
            return books.sorted { $0.lastUpdated > $1.lastUpdated }
        case .title:
            return books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            return books.sorted { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
        case .duration:
            return books.sorted { $0.duration > $1.duration }
        }
    }

    // MARK: - Continue Listening

    /// Returns books that are in progress (started but not finished), sorted by most recently updated.
    func continueListeningBooks(_ books: [CachedBook]) -> [CachedBook] {
        books
            .filter { book in
                guard let progress = book.progress else { return false }
                return progress.currentTime > 0 && !progress.isFinished
            }
            .sorted { ($0.progress?.lastUpdated ?? .distantPast) > ($1.progress?.lastUpdated ?? .distantPast) }
    }
}
