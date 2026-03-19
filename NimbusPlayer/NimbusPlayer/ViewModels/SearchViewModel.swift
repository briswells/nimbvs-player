import Foundation
import SwiftData

// MARK: - SearchViewModel

/// View model that manages search state, results, and recent search history.
@Observable
final class SearchViewModel {
    var query = ""
    var results: [CachedBook] = []
    var seriesResults: [LibraryViewModel.BookGroup] = []
    var isSearching = false
    var recentSearches: [String] = []

    private let recentSearchesKey = "recentSearches"
    private var searchTask: Task<Void, Never>?

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    // MARK: - Search

    /// Debounced search triggered by text changes. Waits briefly for typing to stop.
    func searchDebounced(servers: [Server], serverService: ServerService, allBooks: [CachedBook], modelContext: ModelContext) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(servers: servers, serverService: serverService, allBooks: allBooks, modelContext: modelContext)
        }
    }

    /// Immediate search triggered by submit (pressing return).
    func searchImmediate(servers: [Server], serverService: ServerService, allBooks: [CachedBook], modelContext: ModelContext) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saveRecentSearch(trimmed)
        searchTask = Task {
            await performSearch(servers: servers, serverService: serverService, allBooks: allBooks, modelContext: modelContext)
        }
    }

    /// Core search logic: local substring match + server API search, merged and deduped.
    @MainActor
    private func performSearch(servers: [Server], serverService: ServerService, allBooks: [CachedBook], modelContext: ModelContext) async {
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

        var merged = localResults

        // Only query servers if at least one is reachable
        let hasReachableServer = servers.contains { server in
            server.isActive && serverService.serverStatuses[server.id] == .connected
        }

        if hasReachableServer {
            // Collect (server, items) pairs from all servers
            var serverResults: [(Server, [LibraryItemResponse])] = []
            await withTaskGroup(of: (Server, [LibraryItemResponse]).self) { group in
                for server in servers where server.isActive {
                    guard serverService.serverStatuses[server.id] == .connected,
                          let client = serverService.client(for: server.id) else { continue }
                    group.addTask {
                        var items: [LibraryItemResponse] = []
                        guard let librariesResponse = try? await client.getLibraries() else { return (server, []) }
                        for lib in librariesResponse.libraries where lib.mediaType == "book" {
                            if let response = try? await client.searchLibrary(libraryId: lib.id, query: trimmed) {
                                items.append(contentsOf: response.book?.map(\.libraryItem) ?? [])
                            }
                        }
                        return (server, items)
                    }
                }
                for await result in group {
                    serverResults.append(result)
                }
            }

            for (server, items) in serverResults {
                for item in items {
                    // Check if already cached
                    if let cached = allBooks.first(where: { book in
                        book.serverMappings.contains { $0.libraryItemId == item.id }
                    }) {
                        if !merged.contains(where: { $0.id == cached.id }) {
                            merged.append(cached)
                        }
                    } else {
                        // Not in cache — create a new CachedBook
                        let newBook = CachedBook(
                            title: item.title ?? "Unknown",
                            author: item.authorName ?? "Unknown",
                            duration: item.media.duration ?? item.totalDuration ?? 0,
                            asin: item.asin,
                            isbn: item.isbn,
                            narrator: item.narratorName,
                            bookDescription: item.media.metadata.description,
                            coverPath: item.media.coverPath,
                            seriesName: item.seriesName,
                            seriesSequence: item.seriesSequence
                        )
                        modelContext.insert(newBook)

                        let mapping = ServerBookMapping(
                            server: server,
                            book: newBook,
                            libraryItemId: item.id,
                            libraryId: item.libraryId,
                            bitrate: item.totalBitrate.map { Int($0) },
                            format: item.audioFormat,
                            fileSize: item.totalSize,
                            isPreferred: true
                        )
                        modelContext.insert(mapping)

                        if !merged.contains(where: { $0.id == newBook.id }) {
                            merged.append(newBook)
                        }
                    }
                }
            }
            try? modelContext.save()
        }

        guard !Task.isCancelled else { return }
        results = merged

        // Build series results from cached books whose seriesName matches the query
        var seriesDict: [String: [CachedBook]] = [:]
        for book in allBooks {
            guard let seriesName = book.seriesName, !seriesName.isEmpty else { continue }
            if seriesName.lowercased().contains(lowercaseQuery) {
                seriesDict[seriesName, default: []].append(book)
            }
        }
        seriesResults = seriesDict.map { name, books in
            let sorted = books.sorted { lhs, rhs in
                let lSeq = Double(lhs.seriesSequence ?? "") ?? .greatestFiniteMagnitude
                let rSeq = Double(rhs.seriesSequence ?? "") ?? .greatestFiniteMagnitude
                if lSeq != rSeq { return lSeq < rSeq }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return LibraryViewModel.BookGroup(id: "series:\(name)", name: name, books: sorted)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        isSearching = false
    }

    // MARK: - Clear

    /// Clears the current query and results.
    func clearSearch() {
        searchTask?.cancel()
        query = ""
        results = []
        seriesResults = []
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
