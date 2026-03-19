import Foundation

// MARK: - SearchViewModel

/// View model that manages search state, results, and recent search history.
@Observable
final class SearchViewModel {
    var query = ""
    var results: [CachedBook] = []
    var isSearching = false
    var recentSearches: [String] = []

    private let recentSearchesKey = "recentSearches"

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    // MARK: - Search

    /// Searches locally cached books and active servers for the current query.
    func search(servers: [Server], serverService: ServerService, allBooks: [CachedBook]) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }

        isSearching = true
        saveRecentSearch(query)

        // Search locally first (fast, instant results)
        let lowercaseQuery = query.lowercased()
        let localResults = allBooks.filter {
            $0.title.lowercased().contains(lowercaseQuery) ||
            $0.author.lowercased().contains(lowercaseQuery) ||
            ($0.narrator?.lowercased().contains(lowercaseQuery) ?? false)
        }
        results = localResults

        // Also search servers for items not yet cached
        await withTaskGroup(of: [LibraryItemResponse].self) { group in
            for server in servers where server.isActive {
                guard let client = serverService.client(for: server.id) else { continue }
                group.addTask {
                    var items: [LibraryItemResponse] = []
                    guard let librariesResponse = try? await client.getLibraries() else { return [] }
                    for lib in librariesResponse.libraries where lib.mediaType == "book" {
                        if let response = try? await client.searchLibrary(libraryId: lib.id, query: self.query) {
                            items.append(contentsOf: response.book?.map(\.libraryItem) ?? [])
                        }
                    }
                    return items
                }
            }
            for await serverItems in group {
                for item in serverItems {
                    let alreadyInResults = results.contains { book in
                        BookMatcher.areMatching(
                            BookMatcher.BookIdentity(asin: book.asin, isbn: book.isbn, title: book.title, author: book.author),
                            BookMatcher.BookIdentity(asin: item.asin, isbn: item.isbn, title: item.title ?? "", author: item.authorName ?? "")
                        )
                    }
                    if !alreadyInResults {
                        if let existing = allBooks.first(where: { b in
                            BookMatcher.areMatching(
                                BookMatcher.BookIdentity(asin: b.asin, isbn: b.isbn, title: b.title, author: b.author),
                                BookMatcher.BookIdentity(asin: item.asin, isbn: item.isbn, title: item.title ?? "", author: item.authorName ?? "")
                            )
                        }) {
                            results.append(existing)
                        }
                    }
                }
            }
        }

        isSearching = false
    }

    // MARK: - Clear

    /// Clears the current query and results.
    func clearSearch() {
        query = ""
        results = []
    }

    /// Removes all saved recent searches.
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }

    // MARK: - Private

    private func saveRecentSearch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 10 { recentSearches = Array(recentSearches.prefix(10)) }
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
}
