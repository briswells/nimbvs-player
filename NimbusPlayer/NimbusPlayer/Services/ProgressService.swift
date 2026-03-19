import Foundation
import SwiftData

// MARK: - ProgressService

/// Manages local-first progress tracking with periodic server synchronisation.
///
/// Progress is saved to SwiftData every 5 seconds and synced to the active
/// Audiobookshelf session every 60 seconds. On close, a final sync is sent
/// and the session is terminated on the server.
@Observable
final class ProgressService {

    // MARK: - Properties

    private var syncTimer: Timer?
    private var localSaveTimer: Timer?
    private let keychain = KeychainService()

    // MARK: - Tracking Lifecycle

    /// Starts periodic progress tracking.
    ///
    /// Creates two repeating timers:
    /// - A 5-second timer that saves progress locally to SwiftData.
    /// - A 60-second timer that syncs progress to the active server session.
    ///
    /// - Parameters:
    ///   - playerService: The audio player whose position is tracked.
    ///   - modelContext: The SwiftData context used for local persistence.
    func startTracking(playerService: AudioPlayerService, modelContext: ModelContext) {
        stopTracking()

        localSaveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.saveLocalProgress(playerService: playerService, modelContext: modelContext)
        }

        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.syncToServer(playerService: playerService, modelContext: modelContext)
            }
        }
    }

    /// Stops both the local save and server sync timers.
    func stopTracking() {
        localSaveTimer?.invalidate()
        localSaveTimer = nil
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - Local Save

    /// Saves the current playback position to SwiftData.
    ///
    /// If a `ListeningProgress` record already exists for the book it is updated;
    /// otherwise a new one is created and associated with the book.
    ///
    /// - Parameters:
    ///   - playerService: The audio player whose position is persisted.
    ///   - modelContext: The SwiftData context used for local persistence.
    func saveLocalProgress(playerService: AudioPlayerService, modelContext: ModelContext) {
        guard let book = playerService.currentBook else { return }
        guard playerService.duration > 0 else { return }

        if let progress = book.progress {
            progress.update(currentTime: playerService.currentTime, duration: playerService.duration)
            progress.playbackSpeed = playerService.playbackSpeed
            progress.activeSessionId = playerService.sessionId
            progress.activeSessionServerId = playerService.sessionServerId
        } else {
            let progress = ListeningProgress(
                book: book,
                currentTime: playerService.currentTime,
                totalDuration: playerService.duration
            )
            progress.playbackSpeed = playerService.playbackSpeed
            progress.activeSessionId = playerService.sessionId
            progress.activeSessionServerId = playerService.sessionServerId
            progress.needsSync = true
            modelContext.insert(progress)
            book.progress = progress
        }

        try? modelContext.save()
    }

    // MARK: - Server Sync

    /// Syncs the current playback position to the active server session.
    ///
    /// Uses `KeychainService` to retrieve the token for the active session's
    /// server, then constructs an `APIClient` to POST the sync. Failures are
    /// silently ignored — the local save ensures no data is lost.
    ///
    /// - Parameters:
    ///   - playerService: The audio player whose position is synced.
    ///   - modelContext: The SwiftData context used for local persistence.
    func syncToServer(playerService: AudioPlayerService, modelContext: ModelContext) async {
        guard let book = playerService.currentBook,
              let progress = book.progress,
              let sessionId = progress.activeSessionId,
              let serverId = progress.activeSessionServerId else { return }

        guard let client = buildClient(for: serverId, modelContext: modelContext) else { return }

        let syncRequest = SessionSyncRequest(
            currentTime: playerService.currentTime,
            timeListened: 60,
            duration: playerService.duration
        )

        do {
            try await client.syncSession(sessionId: sessionId, body: syncRequest)
            progress.needsSync = false
            try? modelContext.save()
        } catch {
            // Sync failure is non-fatal; the progress is already saved locally
            // and will be retried on the next timer tick or via flushPendingSyncs.
        }
    }

    /// Performs a final sync of the current position and closes the active session
    /// on the server.
    ///
    /// - Parameters:
    ///   - playerService: The audio player whose session is being closed.
    ///   - modelContext: The SwiftData context used for local persistence.
    func closeSession(playerService: AudioPlayerService, modelContext: ModelContext) async {
        // Save locally first
        saveLocalProgress(playerService: playerService, modelContext: modelContext)

        guard let book = playerService.currentBook,
              let progress = book.progress,
              let sessionId = progress.activeSessionId,
              let serverId = progress.activeSessionServerId else { return }

        guard let client = buildClient(for: serverId, modelContext: modelContext) else { return }

        // Final sync
        let syncRequest = SessionSyncRequest(
            currentTime: playerService.currentTime,
            timeListened: 0,
            duration: playerService.duration
        )

        do {
            try await client.syncSession(sessionId: sessionId, body: syncRequest)
            try await client.closeSession(sessionId: sessionId)
            progress.activeSessionId = nil
            progress.activeSessionServerId = nil
            progress.needsSync = false
            try? modelContext.save()
        } catch {
            // Mark for later sync if the close fails
            progress.needsSync = true
            try? modelContext.save()
        }
    }

    // MARK: - Pull Progress

    /// Fetches progress from all servers that have a mapping for the given book
    /// and applies the most recent position.
    ///
    /// Conflict resolution: if the server position is more than 60 seconds behind
    /// the local position, the local position is kept as a safe default to avoid
    /// accidentally regressing progress.
    ///
    /// - Parameters:
    ///   - book: The book whose progress should be refreshed.
    ///   - serverService: Service providing API clients for each server.
    ///   - modelContext: The SwiftData context used for local persistence.
    func pullProgressFromServers(
        book: CachedBook,
        serverService: ServerService,
        modelContext: ModelContext
    ) async {
        var latestProgress: MediaProgressResponse?
        var latestTimestamp: TimeInterval = 0

        for mapping in book.serverMappings {
            guard let server = mapping.server,
                  let client = serverService.client(for: server.id) else { continue }

            do {
                let remote = try await client.getProgress(libraryItemId: mapping.libraryItemId)
                if remote.lastUpdate > latestTimestamp {
                    latestTimestamp = remote.lastUpdate
                    latestProgress = remote
                }
            } catch {
                // Skip servers that fail — we may still get progress from another.
                continue
            }
        }

        guard let remote = latestProgress else { return }

        let localTime = book.progress?.currentTime ?? 0

        // Conflict resolution: never regress more than 60 seconds without confirmation.
        // For now, keep local position as the safe default when the server is behind.
        if localTime > 0 && remote.currentTime < localTime - 60 {
            return
        }

        if let progress = book.progress {
            progress.update(currentTime: remote.currentTime, duration: remote.duration)
            progress.isFinished = remote.isFinished
            progress.needsSync = false
        } else {
            let progress = ListeningProgress(
                book: book,
                currentTime: remote.currentTime,
                totalDuration: remote.duration
            )
            progress.isFinished = remote.isFinished
            progress.needsSync = false
            modelContext.insert(progress)
            book.progress = progress
        }

        try? modelContext.save()
    }

    // MARK: - Fetch Remote Progress

    /// Fetches the most recent progress from all servers for a book WITHOUT applying it.
    /// Returns the remote progress if found, or nil.
    func fetchRemoteProgress(
        book: CachedBook,
        serverService: ServerService
    ) async -> MediaProgressResponse? {
        var latestProgress: MediaProgressResponse?
        var latestTimestamp: TimeInterval = 0

        for mapping in book.serverMappings {
            guard let server = mapping.server,
                  let client = serverService.client(for: server.id) else { continue }

            do {
                let remote = try await client.getProgress(libraryItemId: mapping.libraryItemId)
                if remote.lastUpdate > latestTimestamp {
                    latestTimestamp = remote.lastUpdate
                    latestProgress = remote
                }
            } catch {
                continue
            }
        }

        return latestProgress
    }

    /// Applies a remote progress response to the local book.
    func applyRemoteProgress(
        _ remote: MediaProgressResponse,
        to book: CachedBook,
        modelContext: ModelContext
    ) {
        if let progress = book.progress {
            progress.update(currentTime: remote.currentTime, duration: remote.duration)
            progress.isFinished = remote.isFinished
            progress.needsSync = false
        } else {
            let progress = ListeningProgress(
                book: book,
                currentTime: remote.currentTime,
                totalDuration: remote.duration
            )
            progress.isFinished = remote.isFinished
            progress.needsSync = false
            modelContext.insert(progress)
            book.progress = progress
        }
        try? modelContext.save()
    }

    // MARK: - Flush Pending Syncs

    /// Pushes all locally-modified progress records to their corresponding servers.
    ///
    /// Finds every `ListeningProgress` record with `needsSync == true` and sends
    /// an update to every server that has a mapping for the associated book.
    ///
    /// - Parameters:
    ///   - modelContext: The SwiftData context used for querying and persistence.
    ///   - serverService: Service providing API clients for each server.
    func flushPendingSyncs(modelContext: ModelContext, serverService: ServerService) async {
        let descriptor = FetchDescriptor<ListeningProgress>(
            predicate: #Predicate<ListeningProgress> { $0.needsSync == true }
        )

        guard let pending = try? modelContext.fetch(descriptor) else { return }

        for progress in pending {
            guard let book = progress.book else { continue }

            var synced = false

            for mapping in book.serverMappings {
                guard let server = mapping.server,
                      let client = serverService.client(for: server.id) else { continue }

                let request = ProgressUpdateRequest(
                    progress: progress.progress,
                    currentTime: progress.currentTime,
                    duration: progress.totalDuration,
                    isFinished: progress.isFinished
                )

                do {
                    try await client.updateProgress(
                        libraryItemId: mapping.libraryItemId,
                        progress: request
                    )
                    synced = true
                } catch {
                    // Continue trying other servers even if one fails.
                    continue
                }
            }

            if synced {
                progress.needsSync = false
            }
        }

        try? modelContext.save()
    }

    // MARK: - Private Helpers

    /// Builds an `APIClient` for the given server ID by fetching the `Server`
    /// from SwiftData and retrieving the authentication token from the Keychain.
    ///
    /// - Parameters:
    ///   - serverId: The UUID of the server to connect to.
    ///   - modelContext: The SwiftData context used to fetch the server record.
    /// - Returns: A configured `APIClient`, or `nil` if the server or token is unavailable.
    private func buildClient(for serverId: UUID, modelContext: ModelContext) -> APIClient? {
        guard let token = try? keychain.getToken(for: serverId),
              token.isEmpty == false else { return nil }

        let descriptor = FetchDescriptor<Server>(
            predicate: #Predicate<Server> { $0.id == serverId }
        )

        guard let server = try? modelContext.fetch(descriptor).first,
              let baseURL = server.baseURL else { return nil }

        return APIClient(baseURL: baseURL, token: token)
    }
}
