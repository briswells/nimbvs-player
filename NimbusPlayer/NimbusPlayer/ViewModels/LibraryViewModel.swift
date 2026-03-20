import Foundation
import SwiftData

// MARK: - LibraryViewModel

/// View model that manages library display state including sorting, layout, grouping, and refresh.
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

    // MARK: - Group Mode

    enum GroupMode: String, CaseIterable {
        case allBooks
        case series
        case authors
        case narrators
        case genres

        var displayName: String {
            switch self {
            case .allBooks: "All Books"
            case .series: "Series"
            case .authors: "Authors"
            case .narrators: "Narrators"
            case .genres: "Genres"
            }
        }

        var icon: String {
            switch self {
            case .allBooks: "books.vertical"
            case .series: "text.book.closed"
            case .authors: "person.2"
            case .narrators: "mic"
            case .genres: "tag"
            }
        }
    }

    // MARK: - BookGroup

    struct BookGroup: Identifiable, Hashable {
        let id: String // group name
        let name: String
        let books: [CachedBook]

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: BookGroup, rhs: BookGroup) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Properties

    var isGridView = true
    var sortOption: SortOption = .recentlyAdded
    var groupMode: GroupMode = .allBooks
    var isRefreshing = false

    private let libraryService: LibraryService

    // MARK: - Init

    init(libraryService: LibraryService = LibraryService()) {
        self.libraryService = libraryService
    }

    // MARK: - Refresh

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

    // MARK: - Grouping

    func groups(from books: [CachedBook]) -> [BookGroup] {
        switch groupMode {
        case .allBooks:
            return []
        case .series:
            return groupBySeries(books)
        case .authors:
            return groupBySplitField(books, label: "author") { $0.author }
        case .narrators:
            return groupBySplitField(books, label: "narrator") { $0.narrator ?? "" }
        case .genres:
            return groupByGenres(books)
        }
    }

    private func groupBySeries(_ books: [CachedBook]) -> [BookGroup] {
        var dict: [String: [CachedBook]] = [:]
        for book in books {
            guard let seriesName = book.seriesName, !seriesName.isEmpty else { continue }
            dict[seriesName, default: []].append(book)
        }
        return dict.map { name, books in
            let sorted = books.sorted { lhs, rhs in
                let lSeq = parseSequenceNumber(lhs.seriesSequence)
                let rSeq = parseSequenceNumber(rhs.seriesSequence)
                if lSeq != rSeq { return lSeq < rSeq }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return BookGroup(id: "series:\(name)", name: name, books: sorted)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Groups books by a comma-separated field (author or narrator).
    /// A book with "Author A, Author B" appears under both "Author A" and "Author B".
    private func groupBySplitField(_ books: [CachedBook], label: String, field: (CachedBook) -> String) -> [BookGroup] {
        var dict: [String: [CachedBook]] = [:]
        for book in books {
            let raw = field(book)
            guard !raw.isEmpty else { continue }
            let names = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            for name in names where !name.isEmpty {
                dict[name, default: []].append(book)
            }
        }
        return dict.map { name, books in
            let sorted = books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return BookGroup(id: "\(label):\(name)", name: name, books: sorted)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func groupByGenres(_ books: [CachedBook]) -> [BookGroup] {
        var dict: [String: [CachedBook]] = [:]
        for book in books {
            for genre in book.genres where !genre.isEmpty {
                dict[genre, default: []].append(book)
            }
        }
        return dict.map { name, books in
            let sorted = books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return BookGroup(id: "genre:\(name)", name: name, books: sorted)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func parseSequenceNumber(_ seq: String?) -> Double {
        guard let seq else { return Double.greatestFiniteMagnitude }
        return Double(seq) ?? Double.greatestFiniteMagnitude
    }

    // MARK: - Continue Listening

    func continueListeningBooks(_ books: [CachedBook]) -> [CachedBook] {
        books
            .filter { book in
                guard let progress = book.progress else { return false }
                return progress.currentTime > 0 && !progress.isFinished
            }
            .sorted { ($0.progress?.lastUpdated ?? .distantPast) > ($1.progress?.lastUpdated ?? .distantPast) }
    }
}
