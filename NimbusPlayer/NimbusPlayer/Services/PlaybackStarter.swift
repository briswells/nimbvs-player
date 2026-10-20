import SwiftData
import SwiftUI

/// Result of a `PlaybackStarter.start` attempt — mirrors the toast/fallback behavior
/// that `BookDetailView` used to handle inline.
enum PlaybackStartResult {
    case started
    case startedOffline
    case startedOnAlternateServer(displayName: String)
    case failed(String)
    case noServerAvailable
}

/// Kicks off playback for a book using the same online-first / offline-fallback path as BookDetailView.
///
/// Creates a server playback session when a server is reachable. Falls back to local files when
/// the book is downloaded. Wires up `ProgressService.startTracking` on success.
struct PlaybackStarter {

    @MainActor
    static func start(
        book: CachedBook,
        startTime: TimeInterval?,
        playerService: AudioPlayerService,
        progressService: ProgressService,
        serverService: ServerService,
        downloadService: DownloadService,
        appState: AppState,
        modelContext: ModelContext
    ) async -> PlaybackStartResult {
        // Close the session being replaced so the server stops treating it as open and records
        // its final listening time.
        if playerService.sessionId != nil {
            await progressService.closeSession(playerService: playerService, modelContext: modelContext)
        }

        // Prefer local files when downloaded — faster and works offline.
        if downloadService.isBookDownloaded(bookId: book.id) {
            playerService.startOfflinePlayback(
                book: book,
                downloadService: downloadService,
                startTime: startTime ?? book.progress?.currentTime
            )
            progressService.startTracking(
                playerService: playerService,
                modelContext: modelContext,
                appState: appState
            )
            return .startedOffline
        }

        guard let mapping = book.preferredMapping,
              let serverId = mapping.server?.id,
              let client = serverService.client(for: serverId) else {
            return .noServerAvailable
        }

        let request = PlaybackSessionRequest.defaultRequest(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            appVersion: "1.0"
        )

        do {
            let session = try await client.startPlaybackSession(
                itemId: mapping.libraryItemId,
                requestBody: request
            )
            playerService.setServerServiceRef(serverService)
            playerService.startPlayback(
                book: book,
                session: session,
                serverId: serverId,
                serverService: serverService,
                startTime: startTime ?? book.progress?.currentTime
            )
            progressService.startTracking(
                playerService: playerService,
                modelContext: modelContext,
                appState: appState
            )
            if mapping.id != book.preferredMapping?.id {
                return .startedOnAlternateServer(displayName: mapping.server?.displayName ?? "alternate server")
            }
            return .started
        } catch {
            if downloadService.isBookDownloaded(bookId: book.id) {
                playerService.startOfflinePlayback(
                    book: book,
                    downloadService: downloadService,
                    startTime: startTime ?? book.progress?.currentTime
                )
                progressService.startTracking(
                    playerService: playerService,
                    modelContext: modelContext,
                    appState: appState
                )
                return .startedOffline
            }
            return .failed(error.localizedDescription)
        }
    }
}
