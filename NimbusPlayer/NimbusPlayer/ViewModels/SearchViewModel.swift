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
    private var searchTask: Task<Void, Never>?

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    // MARK: - Search

    /// Debounced search triggered by text changes. Waits briefly for typing to stop.
    func searchDebounced(servers: [Server], serverService: ServerService, allBooks: [CachedBook]) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(servers: servers, serverService: serverService, allBooks: allBooks)
        }
    }

    /// Immediate search triggered by submit (pressing return).
    func searchImmediate(servers: [Server], serverService: ServerService, allBooks: [CachedBook]) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saveRecentSearch(trimmed)
        searchTask = Task {
            await performSearch(servers: servers, serverService: serverService, allBooks: allBooks)
        }
    }

    /// Core search logic: local substring match + server API search, merged and deduped.
    private func performSearch(servers: [Server], serverService: ServerService, allBooks: [CachedBook]) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        isSearching = true

        // Local substring search across title, author, narrator
        let lowercaseQuery = trimmed.lowercased()
        let localResults = allBooks.filter {
            $0.title.lowercased().contains(lowercaseQuery) ||
            $0.author.lowercased().contains(lowercaseQuery) ||
            ($0.narrator?.lowercased().contains(lowercaseQuery) ?? false)
        }

        // Start with local results
        var merged = localResults

        // Query servers for additional matches
        await withTaskGroup(of: [LibraryItemResponse].self) { group in
            for server in servers where server.isActive {
                guard let client = serverService.client(for: server.id) else { continue }
                group.addTask {
                    var items: [LibraryItemResponse] = []
                    guard let librariesResponse = try? await client.getLibraries() else { return [] }
                    for lib in librariesResponse.libraries where lib.mediaType == "book" {
                        if let response = try? await client.searchLibrary(libraryId: lib.id, query: trimmed) {
                            items.append(contentsOf: response.book?.map(\.libraryItem) ?? [])
                        }
                    }
                    return items
                }
            }
            for await serverItems in group {
                for item in serverItems {
                    // Find the cached book by exact libraryItemId match (not fuzzy).
                    // Fuzzy BookMatcher falsely matches different books in the same series.
                    guard let cached = allBooks.first(where: { book in
                        book.serverMappings.contains { $0.libraryItemId == item.id }
                    }) else { continue }

                    let alreadyPresent = merged.contains { $0.id == cached.id }
                    if !alreadyPresent {
                        merged.append(cached)
                    }
                }
            }
        }

        guard !Task.isCancelled else { return }
        results = merged
        isSearching = false
    }

    // MARK: - Clear

    /// Clears the current query and results.
    func clearSearch() {
        searchTask?.cancel()
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
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 10 { recentSearches = Array(recentSearches.prefix(10)) }
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
}
