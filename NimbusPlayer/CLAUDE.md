# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NimbusPlayer is a native iOS audiobook player app for Audiobookshelf servers. Built with Swift 5.9, SwiftUI, SwiftData, and AVFoundation. Targets iOS 17.0+, iPhone only.

## Build & Development

The project uses **XcodeGen** to generate the Xcode project from `project.yml`.

```bash
# Regenerate Xcode project after changing project.yml or adding/removing files
xcodegen generate

# Build
xcodebuild -scheme NimbusPlayer -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all tests
xcodebuild test -scheme NimbusPlayerTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test (Swift Testing uses @Test functions, not XCTest methods)
xcodebuild test -scheme NimbusPlayerTests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:NimbusPlayerTests/BookMatcherTests
```

After adding or removing Swift files, run `xcodegen generate` to update the Xcode project — source files are auto-discovered from the `NimbusPlayer/` and `NimbusPlayerTests/` directories.

## Architecture

**MVVM + Services** pattern with dependency injection via SwiftUI `@Environment`.

### Service Layer (all `@Observable`, injected from `NimbusPlayerApp`)

- **AudioPlayerService** — AVPlayer-based multi-track playback engine. Manages streaming, sleep timer, chapter navigation, playback speed, Now Playing/Control Center integration, and offline playback from local files.
- **ProgressService** — Local-first progress tracking. Saves to SwiftData every 5s, syncs to server every 60s. Tracks per-book playback speed and completion status.
- **DownloadService** — URLSession background downloads with pause/resume. Files stored in `Documents/Downloads/{bookId}/`.
- **ServerService** — Multi-server connection management. Maintains a pool of `APIClient` instances, one per server. Auth tokens stored in Keychain.
- **LibraryService** — Fetches and merges books from all active servers in parallel. Deduplicates via `BookMatcher` (Jaro-Winkler string similarity) and `UUIDv5` deterministic IDs.
- **APIClient** — HTTP client for the Audiobookshelf REST API. Bearer token auth, 15s timeout.
- **NetworkMonitor** — NWPathMonitor wrapper for connectivity state.

### Data Layer (SwiftData `@Model` classes)

- **Server** — Audiobookshelf connection (URL, username, active status)
- **CachedBook** — Deduplicated audiobook. ID is deterministic via UUIDv5 (from ASIN/ISBN/title/author), so the same book from different servers is one record.
- **ServerBookMapping** — Links a CachedBook to a Server with server-specific metadata (libraryItemId, bitrate, format, fileSize). Has `isPreferred` flag for multi-server selection.
- **ListeningProgress** — Per-book progress with `needsSync` flag for pending server updates.
- **DownloadModel** — Download state machine (queued → downloading → paused → complete/failed).
- **Bookmark** — Timestamped chapter markers with optional notes.

### Key Design Decisions

- **Local-first**: Progress and library data persist to SwiftData first, sync to server asynchronously. App works offline with downloaded books.
- **Multi-server deduplication**: Users can connect multiple Audiobookshelf servers. Books are deduplicated by matching ASIN/ISBN or title+author similarity. Each book gets one `CachedBook` with multiple `ServerBookMapping`s.
- **Background sync**: `BGAppRefreshTask` flushes pending progress syncs every 15 minutes when app is backgrounded.
- **Theme**: `NimbusTheme` provides a custom navy-blue dark mode palette (not stock dark mode). Uses adaptive `UIColor` closures that return custom colors in dark mode and system colors in light mode. Accent colors: pink `#e94560`, purple `#533483`.

### Testing

Tests use the **Swift Testing** framework (`import Testing`, `@Suite`, `@Test`, `#expect`), not XCTest. Unit tests exist for utilities (UUIDv5, BookMatcher, JaroWinkler) and services (APIClient, KeychainService).

## Bundle & App Info

- Bundle ID: `com.nimbvs.player`
- Display Name: "Nimbvs Player"
- Background modes: audio, fetch
- Background task ID: `com.nimbvs.player.progressSync`
