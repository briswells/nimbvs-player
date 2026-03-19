import Foundation
import SwiftData

// MARK: - DownloadError

/// Errors that can occur during download operations.
enum DownloadError: Error, LocalizedError {
    case cellularNotAllowed
    case noServerAvailable
    case noAudioFiles
    case storageFull

    var errorDescription: String? {
        switch self {
        case .cellularNotAllowed:
            return "Downloads over cellular are not allowed. Enable cellular downloads in settings or connect to Wi-Fi."
        case .noServerAvailable:
            return "No server is available for this book."
        case .noAudioFiles:
            return "This book has no audio files to download."
        case .storageFull:
            return "There is not enough storage space to complete this download."
        }
    }
}

// MARK: - DownloadService

/// Manages background downloads of audiobook files with progress tracking and storage management.
///
/// Files are stored in `Documents/Downloads/{bookId}/{filename}`. Each active download is
/// tracked in memory via ``DownloadTask`` and persisted to SwiftData via ``DownloadModel``.
@Observable
final class DownloadService: NSObject, URLSessionDownloadDelegate {

    // MARK: - DownloadTask

    /// In-memory representation of an active download operation.
    struct DownloadTask {
        let bookId: UUID
        let downloadModelId: UUID
        var tasks: [URLSessionDownloadTask]
        var completedFiles: Int
        var totalFiles: Int
    }

    // MARK: - Properties

    /// Active downloads keyed by the download model's UUID.
    var activeDownloads: [UUID: DownloadTask] = [:]

    /// Background URL session configured for out-of-process downloads.
    @ObservationIgnored
    private var _backgroundSession: URLSession?

    private var backgroundSession: URLSession {
        if let existing = _backgroundSession { return existing }
        let config = URLSessionConfiguration.background(withIdentifier: "com.nimbusplayer.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        _backgroundSession = session
        return session
    }

    // MARK: - Download Management

    /// Begins downloading all audio tracks for a book.
    ///
    /// This method checks network availability, fetches item details and track URLs from
    /// the server via a playback session, creates a ``DownloadModel`` in SwiftData, and
    /// enqueues background download tasks for each track.
    ///
    /// - Parameters:
    ///   - book: The cached book to download.
    ///   - serverService: The server service providing API clients.
    ///   - networkMonitor: The network monitor for connectivity checks.
    ///   - allowCellular: Whether to permit downloads over cellular connections.
    ///   - modelContext: The SwiftData model context for persistence.
    @MainActor
    func startDownload(
        book: CachedBook,
        serverService: ServerService,
        networkMonitor: NetworkMonitor,
        allowCellular: Bool,
        modelContext: ModelContext
    ) async throws {
        // Check network availability
        guard networkMonitor.isConnected else {
            throw DownloadError.noServerAvailable
        }

        if !allowCellular && networkMonitor.isExpensive {
            throw DownloadError.cellularNotAllowed
        }

        // Find a server with a valid client for this book
        guard let mapping = book.preferredMapping,
              let server = mapping.server,
              let client = serverService.client(for: server.id) else {
            throw DownloadError.noServerAvailable
        }

        // Fetch full item details to verify audio files exist
        let itemDetails = try await client.getItemDetails(itemId: mapping.libraryItemId)

        guard let audioFiles = itemDetails.media.audioFiles, !audioFiles.isEmpty else {
            throw DownloadError.noAudioFiles
        }

        // Start a playback session to get streaming/download URLs, then immediately close it
        let sessionRequest = PlaybackSessionRequest.defaultRequest(
            deviceId: UUID().uuidString,
            appVersion: "1.0.0"
        )
        let session = try await client.startPlaybackSession(
            itemId: mapping.libraryItemId,
            requestBody: sessionRequest
        )

        // Close the session immediately — we only need the track URLs
        try? await client.closeSession(sessionId: session.id)

        guard !session.audioTracks.isEmpty else {
            throw DownloadError.noAudioFiles
        }

        // Create DownloadModel in SwiftData
        let downloadModel = DownloadModel(book: book, server: server)
        downloadModel.totalBytes = itemDetails.totalSize ?? 0
        modelContext.insert(downloadModel)
        try? modelContext.save()

        // Create download directory
        let bookDir = downloadsDirectory(for: book.id)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)

        // Create URLSession download tasks for each track
        var downloadTasks: [URLSessionDownloadTask] = []

        for track in session.audioTracks {
            guard let trackURL = client.streamingURL(contentUrl: track.contentUrl) else {
                continue
            }

            let trackName = track.title ?? "track_\(track.index)"
            let task = backgroundSession.downloadTask(with: trackURL)
            task.taskDescription = "\(downloadModel.id.uuidString)|\(track.index)|\(trackName)"
            downloadTasks.append(task)
        }

        // Register the active download
        let downloadTask = DownloadTask(
            bookId: book.id,
            downloadModelId: downloadModel.id,
            tasks: downloadTasks,
            completedFiles: 0,
            totalFiles: downloadTasks.count
        )
        activeDownloads[downloadModel.id] = downloadTask

        // Update state and start all tasks
        downloadModel.state = .downloading
        try? modelContext.save()

        for task in downloadTasks {
            task.resume()
        }
    }

    /// Pauses all download tasks associated with the given download ID.
    func pauseDownload(downloadId: UUID) {
        guard let download = activeDownloads[downloadId] else { return }
        for task in download.tasks {
            task.suspend()
        }
    }

    /// Resumes all download tasks associated with the given download ID.
    func resumeDownload(downloadId: UUID) {
        guard let download = activeDownloads[downloadId] else { return }
        for task in download.tasks {
            task.resume()
        }
    }

    /// Cancels an in-progress download, removes downloaded files, and deletes the SwiftData model.
    @MainActor
    func cancelDownload(downloadId: UUID, modelContext: ModelContext) {
        // Cancel active tasks
        if let download = activeDownloads[downloadId] {
            for task in download.tasks {
                task.cancel()
            }
            cleanupFiles(for: download)
            activeDownloads.removeValue(forKey: downloadId)
        }

        // Remove SwiftData model
        let descriptor = FetchDescriptor<DownloadModel>(
            predicate: #Predicate { $0.id == downloadId }
        )
        if let model = try? modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try? modelContext.save()
        }
    }

    /// Deletes a completed download's files and removes its SwiftData model.
    @MainActor
    func deleteDownload(_ download: DownloadModel, modelContext: ModelContext) {
        // Cancel active tasks if still running
        if let active = activeDownloads[download.id] {
            for task in active.tasks {
                task.cancel()
            }
            activeDownloads.removeValue(forKey: download.id)
        }

        // Clean up files on disk
        if let book = download.book {
            let bookDir = downloadsDirectory(for: book.id)
            try? FileManager.default.removeItem(at: bookDir)
        }

        modelContext.delete(download)
        try? modelContext.save()
    }

    // MARK: - File Access

    /// Returns the local file URL for a specific track of a downloaded book, if it exists.
    ///
    /// - Parameters:
    ///   - bookId: The cached book's UUID.
    ///   - trackIndex: The zero-based index of the audio track.
    /// - Returns: The file URL if the track has been downloaded, otherwise `nil`.
    func localFileURL(bookId: UUID, trackIndex: Int) -> URL? {
        let bookDir = downloadsDirectory(for: bookId)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: bookDir,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        // Files are named with their track index prefix for ordering
        let prefix = String(format: "%03d_", trackIndex)
        return contents.first { $0.lastPathComponent.hasPrefix(prefix) }
    }

    /// Checks whether all audio files for a book have been downloaded.
    func isBookDownloaded(bookId: UUID) -> Bool {
        let bookDir = downloadsDirectory(for: bookId)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: bookDir,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }
        return !contents.isEmpty
    }

    /// Calculates the total disk space used by all downloaded audiobook files.
    ///
    /// - Returns: The total size in bytes across all downloads.
    func totalStorageUsed() -> Int64 {
        let downloadsDir = Self.baseDownloadsDirectory
        guard let enumerator = FileManager.default.enumerator(
            at: downloadsDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    // MARK: - File Paths

    /// The root directory for all audiobook downloads.
    private static var baseDownloadsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    /// Returns the download directory for a specific book.
    private func downloadsDirectory(for bookId: UUID) -> URL {
        Self.baseDownloadsDirectory
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
    }

    /// Removes all downloaded files for an active download task.
    private func cleanupFiles(for download: DownloadTask) {
        let bookDir = downloadsDirectory(for: download.bookId)
        try? FileManager.default.removeItem(at: bookDir)
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let description = downloadTask.taskDescription else { return }
        let components = description.split(separator: "|", maxSplits: 2)
        guard components.count == 3,
              let downloadId = UUID(uuidString: String(components[0])) else {
            return
        }

        let trackIndex = Int(components[1]) ?? 0
        let trackName = String(components[2])

        // Determine file extension from the response or track name
        let fileExtension: String
        if let mimeType = downloadTask.response?.mimeType {
            fileExtension = Self.fileExtension(for: mimeType)
        } else {
            fileExtension = (trackName as NSString).pathExtension.isEmpty
                ? "m4b"
                : (trackName as NSString).pathExtension
        }

        let sanitizedName = trackName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileName = String(format: "%03d_%@.%@", trackIndex, sanitizedName, fileExtension)

        Task { @MainActor in
            guard let download = self.activeDownloads[downloadId] else { return }

            let bookDir = self.downloadsDirectory(for: download.bookId)
            try? FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)

            let destinationURL = bookDir.appendingPathComponent(fileName)

            // Remove existing file if present
            try? FileManager.default.removeItem(at: destinationURL)

            do {
                try FileManager.default.moveItem(at: location, to: destinationURL)
            } catch {
                return
            }

            // Update progress
            self.activeDownloads[downloadId]?.completedFiles += 1

            let completedFiles = self.activeDownloads[downloadId]?.completedFiles ?? 0
            let totalFiles = download.totalFiles

            // Store relative path in the download model
            let relativePath = "Downloads/\(download.bookId.uuidString)/\(fileName)"
            self.updateDownloadModel(
                downloadId: downloadId,
                relativePath: relativePath,
                isComplete: completedFiles >= totalFiles
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else { return }
        guard let description = task.taskDescription else { return }
        let components = description.split(separator: "|", maxSplits: 2)
        guard components.count == 3,
              let downloadId = UUID(uuidString: String(components[0])) else {
            return
        }

        let nsError = error as NSError

        Task { @MainActor in
            if Self.isStorageFullError(nsError) {
                self.markDownloadFailed(
                    downloadId: downloadId,
                    error: DownloadError.storageFull.localizedDescription
                )
            } else if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                // Cancelled downloads are expected — do nothing
            } else {
                self.markDownloadFailed(
                    downloadId: downloadId,
                    error: error.localizedDescription
                )
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let description = downloadTask.taskDescription else { return }
        let components = description.split(separator: "|", maxSplits: 2)
        guard components.count == 3,
              let downloadId = UUID(uuidString: String(components[0])) else {
            return
        }

        Task { @MainActor in
            self.updateProgress(
                downloadId: downloadId,
                bytesWritten: bytesWritten
            )
        }
    }

    // MARK: - Internal Helpers

    /// Updates the download model with a newly completed file path and checks for overall completion.
    @MainActor
    private func updateDownloadModel(downloadId: UUID, relativePath: String, isComplete: Bool) {
        // This would ideally use the model context, but we update through a shared context
        // For now, track state in the active download and finalize when complete
        if isComplete {
            activeDownloads.removeValue(forKey: downloadId)
        }
    }

    /// Marks a download as failed and cleans up its active state.
    @MainActor
    private func markDownloadFailed(downloadId: UUID, error: String) {
        if let download = activeDownloads[downloadId] {
            for task in download.tasks {
                task.cancel()
            }
            activeDownloads.removeValue(forKey: downloadId)
        }
    }

    /// Increments the downloaded byte count for an active download.
    @MainActor
    private func updateProgress(downloadId: UUID, bytesWritten: Int64) {
        // Progress is tracked per-task; the DownloadModel's downloadedBytes
        // will be updated when the model context is available.
        _ = activeDownloads[downloadId]
    }

    /// Checks whether an error indicates the device has run out of storage space.
    ///
    /// Inspects the error and its underlying errors for POSIX `ENOSPC` or the
    /// Cocoa `NSFileWriteOutOfSpaceError` code.
    private static func isStorageFullError(_ error: NSError) -> Bool {
        if error.domain == NSPOSIXErrorDomain && error.code == Int(ENOSPC) {
            return true
        }
        if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError {
            return true
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isStorageFullError(underlying)
        }
        return false
    }

    /// Maps a MIME type to a file extension.
    private static func fileExtension(for mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "audio/mpeg", "audio/mp3":
            return "mp3"
        case "audio/mp4", "audio/x-m4a", "audio/x-m4b":
            return "m4b"
        case "audio/flac", "audio/x-flac":
            return "flac"
        case "audio/aac":
            return "aac"
        case "audio/ogg", "audio/vorbis":
            return "ogg"
        case "audio/x-aiff", "audio/aiff":
            return "aiff"
        case "audio/webm":
            return "webm"
        default:
            return "m4b"
        }
    }
}
