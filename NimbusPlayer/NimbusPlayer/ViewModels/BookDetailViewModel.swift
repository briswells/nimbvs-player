import Foundation

// MARK: - BookDetailViewModel

/// View model that loads and formats chapter details for a book's detail screen.
@Observable
final class BookDetailViewModel {

    // MARK: - Properties

    var chapters: [ChapterResponse] = []
    var isLoadingDetails = false

    // MARK: - Loading

    /// Fetches the full item details from the preferred server mapping and extracts chapters.
    /// Caches chapters locally so they're available offline.
    func loadDetails(book: CachedBook, serverService: ServerService) async {
        guard !isLoadingDetails else { return }
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        // Try loading from server first
        if let mapping = book.preferredMapping,
           let serverId = mapping.server?.id,
           let client = serverService.client(for: serverId) {
            do {
                let item = try await client.getItemDetails(itemId: mapping.libraryItemId)
                let fetched = item.media.chapters ?? []
                chapters = fetched
                // Cache for offline use
                cacheChapters(fetched, bookId: book.id)
                return
            } catch {
                // Fall through to cache
            }
        }

        // Offline fallback: load from cache
        chapters = loadCachedChapters(bookId: book.id)
    }

    // MARK: - Chapter Cache

    private func cacheChapters(_ chapters: [ChapterResponse], bookId: UUID) {
        guard let data = try? JSONEncoder().encode(chapters) else { return }
        let url = chapterCacheURL(bookId: bookId)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }

    private func loadCachedChapters(bookId: UUID) -> [ChapterResponse] {
        let url = chapterCacheURL(bookId: bookId)
        guard let data = try? Data(contentsOf: url),
              let chapters = try? JSONDecoder().decode([ChapterResponse].self, from: data) else {
            return []
        }
        return chapters
    }

    private func chapterCacheURL(bookId: UUID) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Chapters", isDirectory: true)
            .appendingPathComponent("\(bookId.uuidString).json")
    }

    // MARK: - Formatting

    func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func formatTimestamp(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}
