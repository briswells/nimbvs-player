import Foundation

// MARK: - NowPlayingViewModel

/// View-model for the Now Playing UI.
///
/// Manages sheet presentation state, scrubber interaction, and provides
/// time / speed formatting helpers consumed by `NowPlayingView` and its children.
@Observable
final class NowPlayingViewModel {

    // MARK: - Sheet State

    var showChapterList = false
    var showSleepTimer = false

    // MARK: - Scrubber State

    var isScrubbing = false
    var scrubPosition: Double = 0

    // MARK: - Speed Options

    /// Ordered list of playback speeds the user can cycle through.
    static let speedOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    /// Returns the next speed in the cycle after the given speed.
    func nextSpeed(after current: Double) -> Double {
        guard let index = Self.speedOptions.firstIndex(of: current) else {
            return 1.0
        }
        let nextIndex = (index + 1) % Self.speedOptions.count
        return Self.speedOptions[nextIndex]
    }

    // MARK: - Formatting

    /// Formats a time interval as `H:MM:SS` or `M:SS`.
    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Formats remaining time as `-H:MM:SS` or `-M:SS`.
    func formatRemaining(_ current: Double, duration: Double) -> String {
        let remaining = max(duration - current, 0)
        return "-\(formatTime(remaining))"
    }

    /// Formats a playback speed as a user-facing string (e.g. "1x", "1.5x").
    func formatSpeed(_ speed: Double) -> String {
        if speed == Double(Int(speed)) {
            return "\(Int(speed))x"
        }
        // Remove trailing zero after decimal if not needed
        let formatted = String(format: "%.2g", speed)
        return "\(formatted)x"
    }
}
