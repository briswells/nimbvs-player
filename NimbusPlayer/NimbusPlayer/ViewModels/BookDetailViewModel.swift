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
    ///
    /// - Parameters:
    ///   - book: The cached book whose details should be loaded.
    ///   - serverService: The service providing API clients for each server.
    func loadDetails(book: CachedBook, serverService: ServerService) async {
        guard !isLoadingDetails else { return }
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        guard let mapping = book.preferredMapping,
              let serverId = mapping.server?.id,
              let client = serverService.client(for: serverId) else {
            return
        }

        do {
            let item = try await client.getItemDetails(itemId: mapping.libraryItemId)
            chapters = item.media.chapters ?? []
        } catch {
            // Silently fail — the view will show an empty chapter list.
        }
    }

    // MARK: - Formatting

    /// Formats a duration in seconds as "Xh Ym".
    ///
    /// Examples: `7260` → `"2h 1m"`, `3540` → `"59m"`, `90060` → `"25h 1m"`
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

    /// Formats a timestamp in seconds as "H:MM:SS" or "M:SS" when under one hour.
    ///
    /// Examples: `3661` → `"1:01:01"`, `125` → `"2:05"`
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
