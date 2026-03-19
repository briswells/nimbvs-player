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
struct DeviceInfo: Codable {
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
                clientName: "Nimbus Player",
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
