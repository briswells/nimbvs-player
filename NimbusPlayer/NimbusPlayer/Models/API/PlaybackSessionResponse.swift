import Foundation
import UIKit

// MARK: - PlaybackSessionResponse

/// Response returned when starting or resuming a playback session.
struct PlaybackSessionResponse: Codable {
    let id: String
    let userId: String?
    let libraryItemId: String
    let episodeId: String?
    let mediaType: String?
    let duration: Double
    let currentTime: Double
    let audioTracks: [AudioTrackResponse]
    let chapters: [ChapterResponse]?
    let displayTitle: String?
    let displayAuthor: String?
    let coverPath: String?
}

// MARK: - AudioTrackResponse

/// A single audio track within a playback session, with streaming URL and offset info.
struct AudioTrackResponse: Codable {
    let index: Int
    let startOffset: Double
    let duration: Double
    let title: String?
    let contentUrl: String
    let mimeType: String
}

// MARK: - PlaybackSessionRequest

/// Request body sent to start a new playback session.
struct PlaybackSessionRequest: Codable {
    let deviceInfo: DeviceInfo
    let forceDirectPlay: Bool
    let forceTranscode: Bool
    let supportedMimeTypes: [String]
    let mediaPlayer: String
}

// MARK: - DeviceInfo

/// Device metadata included in playback session requests.
struct DeviceInfo: Codable, Equatable {
    let deviceId: String
    let clientName: String
    let clientVersion: String
    let manufacturer: String
    let model: String
    let osName: String
    let osVersion: String
}

// MARK: - Default Request Factory

extension PlaybackSessionRequest {

    /// Creates a default playback session request configured for direct play on the current device.
    ///
    /// - Parameters:
    ///   - deviceId: Unique identifier for this device.
    ///   - appVersion: The current app version string.
    /// - Returns: A `PlaybackSessionRequest` suitable for most audiobook playback scenarios.
    static func defaultRequest(deviceId: String, appVersion: String) -> PlaybackSessionRequest {
        PlaybackSessionRequest(
            deviceInfo: DeviceInfo(
                deviceId: deviceId,
                clientName: "Nimbvs Player",
                clientVersion: appVersion,
                manufacturer: "Apple",
                model: UIDevice.current.model,
                osName: UIDevice.current.systemName,
                osVersion: UIDevice.current.systemVersion
            ),
            forceDirectPlay: true,
            forceTranscode: false,
            supportedMimeTypes: [
                "audio/flac",
                "audio/mpeg",
                "audio/mp4",
                "audio/aac",
                "audio/x-aiff",
                "audio/ogg",
                "audio/webm"
            ],
            mediaPlayer: "NimbusPlayer-AVPlayer"
        )
    }
}

// MARK: - SessionSyncRequest

/// Request body sent to sync playback progress with the server.
struct SessionSyncRequest: Codable {
    let currentTime: Double
    let timeListened: Double
    let duration: Double
}

// MARK: - LocalPlaybackSession

/// A listening session for playback from downloaded files, uploaded via `POST /api/session/local`.
///
/// Offline playback never opens a server session, so without this the server records progress
/// but no listening history. Re-posting the same `id` updates the server's copy in place
/// (`currentTime`, `timeListening`, and `updatedAt` are overwritten), so uploads are idempotent.
struct LocalPlaybackSession: Codable, Equatable {
    /// Audiobookshelf's `PlayMethod.LOCAL`.
    static let localPlayMethod = 3

    /// Upper bound on listening time credited for one tracking tick, so a stalled timer
    /// (e.g. the app was suspended) doesn't count the whole gap as listening.
    static let maxTickSeconds: TimeInterval = 15

    var id: String = UUID().uuidString
    let libraryItemId: String
    var mediaType: String = "book"
    let displayTitle: String
    let displayAuthor: String
    let duration: TimeInterval
    var playMethod: Int = LocalPlaybackSession.localPlayMethod
    var mediaPlayer: String = "AVPlayer"
    let deviceInfo: DeviceInfo
    let startTime: TimeInterval
    var currentTime: TimeInterval
    var timeListening: TimeInterval = 0
    /// Milliseconds since 1970, as the server expects.
    let startedAt: Int64
    var updatedAt: Int64

    init(
        libraryItemId: String,
        displayTitle: String,
        displayAuthor: String,
        duration: TimeInterval,
        startTime: TimeInterval,
        startedAt: Date,
        deviceInfo: DeviceInfo
    ) {
        self.libraryItemId = libraryItemId
        self.displayTitle = displayTitle
        self.displayAuthor = displayAuthor
        self.duration = duration
        self.startTime = startTime
        self.currentTime = startTime
        self.deviceInfo = deviceInfo
        self.startedAt = Self.milliseconds(startedAt)
        self.updatedAt = self.startedAt
    }

    /// Credits `seconds` of wall-clock listening (clamped to `0...maxTickSeconds`) and records
    /// the current playback position.
    mutating func recordListening(seconds: TimeInterval, currentTime: TimeInterval, at date: Date) {
        timeListening += min(max(seconds, 0), Self.maxTickSeconds)
        self.currentTime = currentTime
        updatedAt = Self.milliseconds(date)
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}
