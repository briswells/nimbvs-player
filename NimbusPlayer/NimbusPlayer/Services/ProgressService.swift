import Foundation
import SwiftData
import UIKit

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
    var completionThreshold: Double = 1.0
    var completionThresholdMode: CompletionThresholdMode = .percentage
    var completionThresholdSeconds: Int = 300

    /// Listening session for the current offline (downloaded-file) playback, if any.
    @ObservationIgnored private var activeLocalSession: PendingLocalSession?
    @ObservationIgnored private var lastListenTick: Date?
    @ObservationIgnored private let localSessionStore = LocalSessionStore()

    /// Id of the in-progress offline listening session, so history can hide it like a live one.
    var activeLocalSessionId: String? { activeLocalSession?.session.id }

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
    func startTracking(playerService: AudioPlayerService, modelContext: ModelContext, appState: AppState) {
        self.completionThreshold = appState.completionThreshold
        self.completionThresholdMode = appState.completionThresholdMode
        self.completionThresholdSeconds = appState.completionThresholdSeconds
        stopTracking()

        if playerService.isOffline {
            beginLocalSession(playerService: playerService)
        }

        localSaveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            // Defer to next run loop iteration to avoid colliding with SwiftUI renders
            Task { @MainActor in
                self.recordLocalListening(playerService: playerService)
                self.saveLocalProgress(playerService: playerService, modelContext: modelContext)
            }
        }

        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.syncToServer(playerService: playerService, modelContext: modelContext)
                await self.syncPendingLocalSessions(modelContext: modelContext)
            }
        }
    }

    /// Stops both the local save and server sync timers, and ends any offline listening session.
    /// The ended session stays queued on disk until it has been uploaded.
    func stopTracking() {
        localSaveTimer?.invalidate()
        localSaveTimer = nil
        syncTimer?.invalidate()
        syncTimer = nil
        activeLocalSession = nil
        lastListenTick = nil
    }

    // MARK: - Offline Listening Sessions

    /// Starts a local listening session for offline playback of the player's current book.
    ///
    /// Attributed to the book's preferred server mapping (or any mapping with a server); books with
    /// no server mapping can't be reported and are skipped.
    private func beginLocalSession(playerService: AudioPlayerService) {
        guard let book = playerService.currentBook,
              let mapping = book.preferredMapping?.server != nil
                ? book.preferredMapping
                : book.serverMappings.first(where: { $0.server != nil }),
              let serverId = mapping.server?.id else { return }

        let deviceInfo = PlaybackSessionRequest.defaultRequest(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            appVersion: "1.0"
        ).deviceInfo

        activeLocalSession = PendingLocalSession(
            serverId: serverId,
            bookId: book.id,
            session: LocalPlaybackSession(
                libraryItemId: mapping.libraryItemId,
                displayTitle: book.title,
                displayAuthor: book.author,
                duration: playerService.duration,
                startTime: playerService.currentTime,
                startedAt: Date(),
                deviceInfo: deviceInfo
            )
        )
        lastListenTick = Date()
    }

    /// Credits wall-clock time since the last tick to the offline session while audio is playing,
    /// and persists the session so it survives the app being killed before it's uploaded.
    @MainActor
    private func recordLocalListening(playerService: AudioPlayerService) {
        let now = Date()
        defer { lastListenTick = now }

        guard var pending = activeLocalSession,
              let last = lastListenTick,
              playerService.isPlaying,
              playerService.currentBook?.id == pending.bookId else { return }

        pending.session.recordListening(
            seconds: now.timeIntervalSince(last),
            currentTime: playerService.currentTime,
            at: now
        )
        activeLocalSession = pending
        localSessionStore.upsert(pending)
    }

    /// Uploads queued offline listening sessions to their servers.
    ///
    /// Sessions that upload successfully are dropped from the queue unless they're still in
    /// progress or changed while the upload was in flight; those are re-sent on the next pass,
    /// which updates the same session on the server.
    @MainActor
    func syncPendingLocalSessions(modelContext: ModelContext) async {
        for pending in localSessionStore.load() {
            guard let client = buildClient(for: pending.serverId, modelContext: modelContext) else { continue }
            do {
                try await client.syncLocalSession(pending.session)
            } catch APIError.httpError(let statusCode, _) where (400..<500).contains(statusCode) {
                // The server rejected this session outright; retrying won't help.
            } catch {
                continue
            }
            if pending.session.id != activeLocalSession?.session.id {
                localSessionStore.remove(pending)
            }
        }
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
        let currentTime = playerService.currentTime
        let duration = playerService.duration

        // Reject obviously invalid positions (e.g. a stale currentTime left
        // over from a different book whose duration was longer).
        guard currentTime >= 0, currentTime <= duration + 5 else { return }

        if let progress = book.progress {
            // Only save if position changed by at least 1 second
            guard abs(progress.currentTime - currentTime) >= 1.0 || playerService.didFinishBook else { return }
            progress.update(currentTime: currentTime, duration: duration, completionThreshold: effectiveThreshold(forDuration: duration))
            progress.playbackSpeed = playerService.playbackSpeed
            progress.activeSessionId = playerService.sessionId
            progress.activeSessionServerId = playerService.sessionServerId
        } else {
            let progress = ListeningProgress(
                book: book,
                currentTime: currentTime,
                totalDuration: duration
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
    @MainActor
    func syncToServer(playerService: AudioPlayerService, modelContext: ModelContext) async {
        guard let book = playerService.currentBook,
              let progress = book.progress,
              let sessionId = progress.activeSessionId,
              let serverId = progress.activeSessionServerId else { return }

        guard let client = buildClient(for: serverId, modelContext: modelContext) else { return }

        // Capture values before await to avoid stale SwiftData references
        let currentTime = playerService.currentTime
        let duration = playerService.duration

        let syncRequest = SessionSyncRequest(
            currentTime: currentTime,
            timeListened: 60,
            duration: duration
        )

        do {
            try await client.syncSession(sessionId: sessionId, body: syncRequest)

            // If the book is finished, also update progress via the dedicated endpoint
            // so the server records the isFinished flag (SessionSyncRequest doesn't carry it).
            if let freshProgress = book.progress, freshProgress.isFinished {
                if let mapping = book.preferredMapping {
                    let update = ProgressUpdateRequest(
                        progress: freshProgress.progress,
                        currentTime: currentTime,
                        duration: duration,
                        isFinished: true
                    )
                    try? await client.updateProgress(libraryItemId: mapping.libraryItemId, progress: update)
                }
            }

            // Re-fetch progress after await — the reference may be stale
            if let freshProgress = book.progress {
                freshProgress.needsSync = false
                try? modelContext.save()
            }
        } catch {
            // Sync failure is non-fatal
        }
    }

    /// Performs a final sync of the current position and closes the active session
    /// on the server.
    ///
    /// - Parameters:
    ///   - playerService: The audio player whose session is being closed.
    ///   - modelContext: The SwiftData context used for local persistence.
    @MainActor
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

            // Send isFinished to the server via the progress endpoint
            if progress.isFinished, let mapping = book.preferredMapping {
                let update = ProgressUpdateRequest(
                    progress: progress.progress,
                    currentTime: playerService.currentTime,
                    duration: playerService.duration,
                    isFinished: true
                )
                try? await client.updateProgress(libraryItemId: mapping.libraryItemId, progress: update)
            }

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
    @MainActor
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

        let effectivePct = effectiveThreshold(forDuration: remote.duration)
        let isFinished = remote.isFinished || (remote.duration > 0 && (remote.currentTime / remote.duration) >= effectivePct)

        let serverDate = Date(timeIntervalSince1970: remote.lastUpdate / 1000)

        if let progress = book.progress {
            progress.update(currentTime: remote.currentTime, duration: remote.duration, completionThreshold: effectivePct)
            progress.isFinished = isFinished
            progress.serverLastUpdate = serverDate
            progress.needsSync = false
        } else {
            let progress = ListeningProgress(
                book: book,
                currentTime: remote.currentTime,
                totalDuration: remote.duration
            )
            progress.isFinished = isFinished
            progress.serverLastUpdate = serverDate
            progress.needsSync = false
            modelContext.insert(progress)
            book.progress = progress
        }

        try? modelContext.save()
    }

    // MARK: - Bulk Progress Sync

    /// Pulls all progress from all servers in one call per server and applies to cached books.
    /// Used on first load / library refresh to populate "Continue Listening" without opening each book.
    @MainActor
    func syncAllProgress(
        servers: [Server],
        serverService: ServerService,
        modelContext: ModelContext
    ) async {
        // Fetch all cached books up front to match by libraryItemId
        let allBooks: [CachedBook]
        do {
            allBooks = try modelContext.fetch(FetchDescriptor<CachedBook>())
        } catch {
            return
        }

        // Build a lookup: libraryItemId → CachedBook
        var itemIdToBook: [String: CachedBook] = [:]
        for book in allBooks {
            for mapping in book.serverMappings {
                itemIdToBook[mapping.libraryItemId] = book
            }
        }

        for server in servers where server.isActive {
            guard let client = serverService.client(for: server.id) else { continue }

            guard let user = try? await client.getMe(),
                  let progressList = user.mediaProgress else { continue }

            for remote in progressList {
                guard remote.currentTime > 0 || remote.isFinished else { continue }
                guard let book = itemIdToBook[remote.libraryItemId] else { continue }

                let localTime = book.progress?.currentTime ?? 0
                let localUpdate = book.progress?.lastUpdated ?? .distantPast
                let remoteDate = Date(timeIntervalSince1970: remote.lastUpdate / 1000)

                // Always update the server timestamp for Continue Listening ordering
                if let progress = book.progress {
                    progress.serverLastUpdate = remoteDate
                }

                // Never let the server regress local progress by more than 60s
                // unless the book is explicitly marked finished. Protects against
                // transient auth/session desync returning stale or zeroed state.
                if !remote.isFinished && localTime > 0 && remote.currentTime < localTime - 60 {
                    continue
                }

                if localTime == 0 && remote.currentTime > 0 {
                    applyRemoteProgress(remote, to: book, modelContext: modelContext)
                } else if remoteDate > localUpdate && abs(remote.currentTime - localTime) > 30 {
                    applyRemoteProgress(remote, to: book, modelContext: modelContext)
                }
            }
        }
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
    /// Uses the local completion threshold to determine `isFinished` — if the server
    /// says finished OR the local threshold is met, the book is marked finished.
    func applyRemoteProgress(
        _ remote: MediaProgressResponse,
        to book: CachedBook,
        modelContext: ModelContext
    ) {
        let effectivePct = effectiveThreshold(forDuration: remote.duration)
        let isFinished = remote.isFinished || (remote.duration > 0 && (remote.currentTime / remote.duration) >= effectivePct)

        let serverDate = Date(timeIntervalSince1970: remote.lastUpdate / 1000)

        if let progress = book.progress {
            progress.update(currentTime: remote.currentTime, duration: remote.duration, completionThreshold: effectivePct)
            progress.isFinished = isFinished
            progress.serverLastUpdate = serverDate
            progress.needsSync = false
        } else {
            let progress = ListeningProgress(
                book: book,
                currentTime: remote.currentTime,
                totalDuration: remote.duration
            )
            progress.isFinished = isFinished
            progress.serverLastUpdate = serverDate
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
        await syncPendingLocalSessions(modelContext: modelContext)

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

                // Only send isFinished when true — never un-finish a book on the server
                let request = ProgressUpdateRequest(
                    progress: progress.progress,
                    currentTime: progress.currentTime,
                    duration: progress.totalDuration,
                    isFinished: progress.isFinished ? true : nil
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

    // MARK: - Re-evaluate Completion Threshold

    /// Re-checks all books against the current completion settings and marks newly qualifying
    /// books as finished. Never un-finishes a book — the server is authoritative for that.
    @MainActor
    func reapplyCompletionThreshold(
        appState: AppState,
        modelContext: ModelContext,
        serverService: ServerService
    ) async {
        self.completionThreshold = appState.completionThreshold
        self.completionThresholdMode = appState.completionThresholdMode
        self.completionThresholdSeconds = appState.completionThresholdSeconds

        let descriptor = FetchDescriptor<ListeningProgress>()
        guard let allProgress = try? modelContext.fetch(descriptor) else { return }

        for progress in allProgress {
            guard progress.totalDuration > 0 else { continue }
            guard !progress.isFinished else { continue } // never un-finish
            let effectivePct = effectiveThreshold(forDuration: progress.totalDuration)
            if progress.progress >= effectivePct {
                progress.isFinished = true
                progress.needsSync = true
                progress.lastUpdated = Date()
            }
        }

        try? modelContext.save()
        await flushPendingSyncs(modelContext: modelContext, serverService: serverService)
    }

    /// Returns the effective percentage threshold for a book of the given duration.
    func effectiveThreshold(forDuration duration: TimeInterval) -> Double {
        switch completionThresholdMode {
        case .percentage:
            return completionThreshold
        case .timeRemaining:
            guard duration > 0 else { return 1.0 }
            return max(0, (duration - Double(completionThresholdSeconds)) / duration)
        }
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

        return APIClient(baseURL: baseURL, token: token, serverId: serverId)
    }
}

// MARK: - Pending Local Sessions

/// An offline listening session plus what's needed to upload it later.
struct PendingLocalSession: Codable, Equatable {
    let serverId: UUID
    let bookId: UUID
    var session: LocalPlaybackSession
}

/// File-backed queue of offline listening sessions awaiting upload.
///
/// Stored as JSON in Application Support so sessions survive relaunches and long offline spells.
struct LocalSessionStore {
    let fileURL: URL

    init(fileURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PendingLocalSessions.json")) {
        self.fileURL = fileURL
    }

    func load() -> [PendingLocalSession] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PendingLocalSession].self, from: data)) ?? []
    }

    /// Inserts the session, or replaces the queued copy with the same id.
    func upsert(_ pending: PendingLocalSession) {
        var all = load()
        if let index = all.firstIndex(where: { $0.session.id == pending.session.id }) {
            all[index] = pending
        } else {
            all.append(pending)
        }
        save(all)
    }

    /// Removes the queued session only if it's unchanged from `pending`, so time recorded after
    /// `pending` was read isn't lost.
    func remove(_ pending: PendingLocalSession) {
        save(load().filter { $0 != pending })
    }

    private func save(_ all: [PendingLocalSession]) {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
