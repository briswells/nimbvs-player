import AVFoundation
import MediaPlayer
import SwiftUI

// MARK: - AudioPlayerService

/// Core audio playback engine for Nimbus Player.
///
/// Manages multi-track audiobook playback with streaming support, sleep timer,
/// chapter navigation, and Now Playing / Remote Command integration.
@Observable
final class AudioPlayerService {

    // MARK: - Published State

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var currentTrackIndex: Int = 0
    private(set) var isBuffering = false

    var currentBook: CachedBook?
    var playbackSpeed: Double = 1.0
    var chapters: [ChapterResponse] = []

    // Session info
    private(set) var sessionId: String?
    private(set) var sessionServerId: UUID?

    // Sleep timer
    var sleepTimerRemaining: TimeInterval?
    private var sleepTimer: Timer?

    // MARK: - Private

    private var player: AVPlayer?
    private var tracks: [AudioTrackResponse] = []
    private var timeObserver: Any?
    private var pausedAt: Date?
    private var statusObservation: NSKeyValueObservation?

    /// Weak reference to the server service, set externally to avoid a strong retain cycle.
    private weak var _serverService: ServerService?

    // MARK: - Server Service Reference

    /// Stores a weak reference to the server service for use during cross-track seeking.
    func setServerServiceRef(_ service: ServerService) {
        _serverService = service
    }

    // MARK: - Playback Control

    /// Sets up tracks from the playback session response, finds the correct track
    /// for the resume time, and begins playback.
    ///
    /// - Parameters:
    ///   - book: The cached book to play.
    ///   - session: The server playback session containing audio tracks and chapters.
    ///   - serverId: The UUID of the server providing the stream.
    ///   - serverService: The server service used to obtain API clients.
    ///   - startTime: An optional override for the resume position; defaults to the session's current time.
    func startPlayback(
        book: CachedBook,
        session: PlaybackSessionResponse,
        serverId: UUID,
        serverService: ServerService,
        startTime: TimeInterval? = nil
    ) {
        self.currentBook = book
        self.sessionId = session.id
        self.sessionServerId = serverId
        self.tracks = session.audioTracks.sorted(by: { $0.index < $1.index })
        self.chapters = session.chapters ?? []
        self.duration = session.duration

        // Use per-book speed if available, otherwise keep current speed
        self.playbackSpeed = book.progress?.playbackSpeed ?? playbackSpeed

        let resumeTime = startTime ?? session.currentTime

        // Find the correct track for the resume time
        guard let (trackIndex, trackLocalTime) = findTrack(for: resumeTime) else { return }

        setupAudioSession()
        loadTrack(at: trackIndex, seekTo: trackLocalTime, serverId: serverId, serverService: serverService)
    }

    /// Resumes playback at the current playback speed.
    ///
    /// If the player was paused for longer than 2 minutes, rewinds 5 seconds
    /// before resuming to help the listener re-orient.
    func play() {
        // Resume rewind if paused for > 2 minutes
        if let pausedAt, Date().timeIntervalSince(pausedAt) > 120 {
            let rewindAmount: TimeInterval = 5.0
            let newTime = max(0, currentTime - rewindAmount)
            seek(to: newTime)
        }
        pausedAt = nil
        player?.rate = Float(playbackSpeed)
        isPlaying = true
        updateNowPlayingInfo()
    }

    /// Pauses playback and records the pause timestamp for resume-rewind logic.
    func pause() {
        player?.pause()
        isPlaying = false
        pausedAt = Date()
        updateNowPlayingInfo()
    }

    /// Toggles between play and pause states.
    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    /// Seeks to an absolute position within the book's global timeline.
    ///
    /// If the target time falls in a different track, loads that track first.
    /// - Parameter globalTime: The target position in seconds from the start of the book.
    func seek(to globalTime: TimeInterval) {
        guard let (trackIndex, localTime) = findTrack(for: globalTime) else { return }

        if trackIndex != currentTrackIndex, let serverId = sessionServerId {
            // Need to load a different track
            if let serverService = findServerService() {
                loadTrack(at: trackIndex, seekTo: localTime, serverId: serverId, serverService: serverService)
            }
        } else {
            let cmTime = CMTime(seconds: localTime, preferredTimescale: 600)
            player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime = globalTime
        }
        updateNowPlayingInfo()
    }

    /// Skips forward by the specified number of seconds.
    func skipForward(_ seconds: TimeInterval = 30) {
        seek(to: min(currentTime + seconds, duration))
    }

    /// Skips backward by the specified number of seconds.
    func skipBackward(_ seconds: TimeInterval = 30) {
        seek(to: max(currentTime - seconds, 0))
    }

    /// Changes the playback speed and applies it immediately if currently playing.
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = Float(speed)
        }
    }

    /// Stops playback entirely, releasing the player and resetting all state.
    func stop() {
        player?.pause()
        removeTimeObserver()
        player = nil
        isPlaying = false
        currentBook = nil
        sessionId = nil
        tracks = []
        chapters = []
        cancelSleepTimer()
    }

    // MARK: - Sleep Timer

    /// Starts a countdown sleep timer that will fade out and pause after the given number of minutes.
    func setSleepTimer(minutes: TimeInterval) {
        cancelSleepTimer()
        sleepTimerRemaining = minutes * 60
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            Task { @MainActor in
                if var remaining = self.sleepTimerRemaining {
                    remaining -= 1
                    if remaining <= 0 {
                        self.fadeOutAndPause()
                        self.cancelSleepTimer()
                    } else {
                        self.sleepTimerRemaining = remaining
                    }
                }
            }
        }
    }

    /// Activates end-of-chapter sleep mode.
    ///
    /// Uses a sentinel value of -1 for `sleepTimerRemaining`. The time observer checks
    /// for this and triggers a fade-out when the current chapter is about to end.
    func setSleepTimerEndOfChapter() {
        cancelSleepTimer()
        sleepTimerRemaining = -1
    }

    /// Cancels any active sleep timer and clears the remaining time.
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = nil
    }

    // MARK: - Chapter Navigation

    /// The chapter that contains the current playback position, if any.
    var currentChapter: ChapterResponse? {
        chapters.first { currentTime >= $0.start && currentTime < $0.end }
    }

    /// Seeks to the start of the specified chapter.
    func seekToChapter(_ chapter: ChapterResponse) {
        seek(to: chapter.start)
    }

    /// Advances to the next chapter, if one exists.
    func nextChapter() {
        guard let current = currentChapter,
              let index = chapters.firstIndex(where: { $0.id == current.id }),
              index + 1 < chapters.count else { return }
        seekToChapter(chapters[index + 1])
    }

    /// Returns to the previous chapter, if one exists.
    func previousChapter() {
        guard let current = currentChapter,
              let index = chapters.firstIndex(where: { $0.id == current.id }),
              index > 0 else { return }
        seekToChapter(chapters[index - 1])
    }

    // MARK: - Multi-Track Timeline

    /// Maps a global time (seconds from book start) to the correct track index and local offset.
    ///
    /// - Parameter globalTime: Position in the book's overall timeline.
    /// - Returns: A tuple of `(trackIndex, localTime)`, or `nil` if no tracks are loaded.
    private func findTrack(for globalTime: TimeInterval) -> (trackIndex: Int, localTime: TimeInterval)? {
        for (index, track) in tracks.enumerated() {
            if globalTime >= track.startOffset && globalTime < track.startOffset + track.duration {
                return (index, globalTime - track.startOffset)
            }
        }
        // If past all tracks, return last track at its end
        if let last = tracks.last {
            return (tracks.count - 1, last.duration)
        }
        return nil
    }

    /// Loads a specific audio track and seeks to the given position within it.
    ///
    /// - Parameters:
    ///   - index: The index of the track to load.
    ///   - seekTo: The local offset within the track to seek to.
    ///   - serverId: The server providing the stream.
    ///   - serverService: The server service used to obtain the streaming URL.
    private func loadTrack(at index: Int, seekTo: TimeInterval, serverId: UUID, serverService: ServerService) {
        guard index < tracks.count else { return }

        removeTimeObserver()
        let track = tracks[index]
        currentTrackIndex = index

        guard let client = serverService.client(for: serverId),
              let url = client.streamingURL(contentUrl: track.contentUrl) else { return }

        isBuffering = true
        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        // Observe buffering state via timeControlStatus
        statusObservation = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        // Observe end of track to advance to the next one
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.advanceToNextTrack(serverService: serverService, serverId: serverId)
        }

        // Seek to position within track, then begin playback
        let cmTime = CMTime(seconds: seekTo, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.play()
        }

        addTimeObserver()
    }

    /// Advances to the next track in the sequence, or pauses if the book is finished.
    private func advanceToNextTrack(serverService: ServerService, serverId: UUID) {
        let nextIndex = currentTrackIndex + 1
        if nextIndex < tracks.count {
            loadTrack(at: nextIndex, seekTo: 0, serverId: serverId, serverService: serverService)
        } else {
            // Book finished
            pause()
        }
    }

    // MARK: - Time Observer

    /// Installs a periodic time observer that fires every 0.5 seconds to update the current position
    /// and check for end-of-chapter sleep timer conditions.
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, self.currentTrackIndex < self.tracks.count else { return }
            let trackTime = time.seconds
            let track = self.tracks[self.currentTrackIndex]
            self.currentTime = track.startOffset + trackTime

            // Check sleep timer end-of-chapter sentinel
            if self.sleepTimerRemaining == -1, let chapter = self.currentChapter {
                let timeToEnd = chapter.end - self.currentTime
                if timeToEnd <= 3 && timeToEnd > 0 {
                    self.fadeOutAndPause()
                    self.cancelSleepTimer()
                }
            }
        }
    }

    /// Removes the periodic time observer from the player.
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    // MARK: - Sleep Timer Fade

    /// Gradually fades the volume to zero over 3 seconds, then pauses and restores volume.
    private func fadeOutAndPause() {
        let steps = 30
        let interval = 3.0 / Double(steps)
        let originalVolume = player?.volume ?? 1.0

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) { [weak self] in
                self?.player?.volume = originalVolume * (1.0 - Float(i) / Float(steps))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.pause()
            self?.player?.volume = originalVolume
        }
    }

    // MARK: - Audio Session

    /// Configures the audio session for audiobook playback with background audio support.
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }

        setupRemoteCommands()
    }

    // MARK: - Remote Commands

    /// Registers handlers for all supported remote control commands (lock screen, Control Center, AirPods).
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] event in
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            self?.skipForward(event.interval)
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [30]
        center.skipBackwardCommand.addTarget { [weak self] event in
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            self?.skipBackward(event.interval)
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextChapter()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousChapter()
            return .success
        }
    }

    // MARK: - Now Playing Info

    /// Updates the system Now Playing info center with the current book, chapter, and playback state.
    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentBook?.title ?? ""
        info[MPMediaItemPropertyArtist] = currentBook?.author ?? ""
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0
        if let chapter = currentChapter {
            info[MPMediaItemPropertyAlbumTitle] = chapter.title
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Private Helpers

    private func findServerService() -> ServerService? {
        _serverService
    }
}
