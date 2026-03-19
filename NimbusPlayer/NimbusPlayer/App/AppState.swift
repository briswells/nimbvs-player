import SwiftUI

// MARK: - Double Extension

extension Double {
    /// Returns self if non-zero, otherwise returns the provided default value.
    func nonZero(default defaultValue: Double) -> Double {
        self != 0 ? self : defaultValue
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - App State

@Observable
final class AppState {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let defaultPlaybackSpeed = "defaultPlaybackSpeed"
        static let skipForwardDuration = "skipForwardDuration"
        static let skipBackwardDuration = "skipBackwardDuration"
        static let resumeRewindSeconds = "resumeRewindSeconds"
        static let downloadOverCellular = "downloadOverCellular"
        static let autoRemoveFinishedDownloads = "autoRemoveFinishedDownloads"
        static let appearanceMode = "appearanceMode"
    }

    private let defaults: UserDefaults

    // MARK: - Settings

    var defaultPlaybackSpeed: Double {
        didSet { defaults.set(defaultPlaybackSpeed, forKey: Keys.defaultPlaybackSpeed) }
    }

    var skipForwardDuration: Int {
        didSet { defaults.set(skipForwardDuration, forKey: Keys.skipForwardDuration) }
    }

    var skipBackwardDuration: Int {
        didSet { defaults.set(skipBackwardDuration, forKey: Keys.skipBackwardDuration) }
    }

    var resumeRewindSeconds: Int {
        didSet { defaults.set(resumeRewindSeconds, forKey: Keys.resumeRewindSeconds) }
    }

    var downloadOverCellular: Bool {
        didSet { defaults.set(downloadOverCellular, forKey: Keys.downloadOverCellular) }
    }

    var autoRemoveFinishedDownloads: Bool {
        didSet { defaults.set(autoRemoveFinishedDownloads, forKey: Keys.autoRemoveFinishedDownloads) }
    }

    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.defaultPlaybackSpeed = defaults.double(forKey: Keys.defaultPlaybackSpeed)
            .nonZero(default: 1.0)

        let forward = defaults.integer(forKey: Keys.skipForwardDuration)
        self.skipForwardDuration = forward != 0 ? forward : 30

        let backward = defaults.integer(forKey: Keys.skipBackwardDuration)
        self.skipBackwardDuration = backward != 0 ? backward : 30

        let rewind = defaults.integer(forKey: Keys.resumeRewindSeconds)
        self.resumeRewindSeconds = rewind != 0 ? rewind : 5

        self.downloadOverCellular = defaults.bool(forKey: Keys.downloadOverCellular)
        self.autoRemoveFinishedDownloads = defaults.bool(forKey: Keys.autoRemoveFinishedDownloads)

        let modeString = defaults.string(forKey: Keys.appearanceMode) ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: modeString) ?? .system
    }
}
