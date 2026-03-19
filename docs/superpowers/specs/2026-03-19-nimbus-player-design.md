# Nimbus Player — Design Specification

## Overview

Nimbus Player is an iOS audiobook listening app that connects to one or more Audiobookshelf servers. It prioritizes listening progress tracking, offline downloads, and easy library browsing. No server management features — purely a client/listener app.

- **Platform:** iOS 17+
- **Language:** Swift
- **UI Framework:** SwiftUI
- **Architecture:** MVVM with service layer
- **Dependencies:** None (pure Apple frameworks)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (Observable macro, NavigationStack) |
| Persistence | SwiftData |
| Networking | URLSession (async/await) |
| Audio | AVFoundation (AVPlayer) |
| Lock Screen / CarPlay | MediaPlayer (MPNowPlayingInfoCenter, MPRemoteCommandCenter) |
| Secure Storage | Keychain (server tokens) |
| Network Monitoring | Network framework (NWPathMonitor) |

## App Architecture

```
Views (SwiftUI)
  └── ViewModels (@Observable)
        └── Services (injected via SwiftUI Environment)
              ├── AudioPlayerService    — AVPlayer, playback state, now playing info
              ├── ServerService         — API calls, auth, multi-server management
              ├── LibraryService        — merged library, deduplication, search
              ├── ProgressService       — local progress tracking, sync to servers
              └── DownloadService       — offline file management
```

## Data Models (SwiftData)

### Server
- `id`: UUID
- `url`: String
- `username`: String
- `displayName`: String
- `isActive`: Bool
- `lastConnected`: Date?
- Token stored in Keychain, keyed by server ID

### CachedBook
- `id`: UUID (deterministically generated from dedup key — see note below)
- `title`: String
- `author`: String
- `narrator`: String?
- `asin`: String?
- `isbn`: String?
- `description`: String?
- `duration`: TimeInterval
- `coverUrl`: String?
- `seriesName`: String?
- `seriesSequence`: String?
- `serverMappings`: [ServerBookMapping]
- `lastUpdated`: Date

**CachedBook ID generation:** To ensure stable identity across app reinstalls, the UUID is deterministically derived: if ASIN exists, `UUID(name: "asin:{asin}")` (UUID v5); if ISBN, `UUID(name: "isbn:{isbn}")`; otherwise `UUID(name: "title:{normalizedTitle}|author:{normalizedAuthor}")`. This means progress and downloads survive database resets as long as the book can be re-matched.

### ServerBookMapping
- `id`: UUID
- `server`: Server (relationship)
- `book`: CachedBook (relationship)
- `libraryItemId`: String (server-specific item ID)
- `bitrate`: Int?
- `format`: String? (e.g., "mp3", "m4b")
- `fileSize`: Int64?
- `isPreferred`: Bool (user's chosen server for this book)

### ListeningProgress
- `id`: UUID
- `book`: CachedBook (relationship)
- `currentTime`: TimeInterval
- `totalDuration`: TimeInterval
- `progress`: Double (0.0–1.0)
- `isFinished`: Bool
- `playbackSpeed`: Double? (nil = use global default)
- `lastUpdated`: Date
- `needsSync`: Bool (dirty flag for offline changes)

Note: Current chapter is derived at display time from `currentTime` and the chapter list, not stored. This avoids stale references if server chapter metadata changes.

### Download
- `id`: UUID
- `book`: CachedBook (relationship)
- `server`: Server (relationship)
- `state`: DownloadState (queued/downloading/paused/complete/failed)
- `totalBytes`: Int64
- `downloadedBytes`: Int64
- `relativeFilePaths`: [String] (relative to app's Documents directory — resolved at runtime to avoid iOS sandbox path changes)
- `dateStarted`: Date
- `dateCompleted`: Date?

### Bookmark
- `id`: UUID
- `book`: CachedBook (relationship)
- `timestamp`: TimeInterval
- `note`: String?
- `dateCreated`: Date

## Authentication

- Audiobookshelf uses POST `/login` with `{ username, password }` → returns user object with `token`
- Token used as `Authorization: Bearer <token>` header on all subsequent requests
- Token stored in Keychain per server
- On app launch, validate token with GET `/api/authorize` for each server
- If token expired/invalid, prompt re-authentication
- **Mid-session token expiry:** If an API call returns 401 during playback or download:
  - Playback continues (audio is already buffered/streaming) but sync calls are queued
  - A non-blocking banner appears: "Session expired for [Server] — tap to re-authenticate"
  - On re-auth, queued syncs flush immediately
  - Downloads pause and resume after re-auth
  - If another server has the book, fallback to that server for sync

## Multi-Server Design

### Server Management
- Settings screen: add, edit, remove servers
- Each server shows connection status indicator (connected/unreachable)
- All active servers queried concurrently on app launch and pull-to-refresh

### Book Deduplication Algorithm
1. Fetch all library items from all active servers in parallel (paginated at 100 items per page)
2. For each item, extract: ASIN, ISBN, title, author
3. Matching priority:
   - **Exact ASIN match** → same book
   - **Exact ISBN match** → same book
   - **Fuzzy title + author match** using Jaro-Winkler similarity:
     - Normalize: lowercase, trim whitespace, strip subtitle (split on `:` or ` - `, take first part), remove leading "The "/"A "/"An "
     - Compare title and author independently, both must score ≥ 0.85
     - If only one field scores ≥ 0.85, do not match (avoids false positives from common authors with different books)
4. Matched items grouped into a single CachedBook with multiple ServerBookMappings
5. Unmatched items become standalone CachedBook entries

### Server Preference & Fallback
- When a book exists on multiple servers, user picks preferred server from book detail view
- Comparison shows: bitrate, format, file size per server
- Preference persists via `isPreferred` flag on ServerBookMapping
- On playback start: try preferred server first
- If unreachable (5s timeout): try other servers with same book
- Sync local progress to fallback server before starting playback
- Show toast: "Playing from [Server Name]"

## Audio Playback

### Playback Session Lifecycle
1. POST `/api/items/{id}/play` with request body:
   ```json
   {
     "deviceInfo": {
       "deviceId": "<unique device UUID>",
       "clientName": "Nimbus Player",
       "clientVersion": "<app version>",
       "manufacturer": "Apple",
       "model": "<iPhone model>",
       "osName": "iOS",
       "osVersion": "<iOS version>"
     },
     "forceTranscode": false,
     "mediaPlayer": "AVPlayer"
   }
   ```
2. Response is a `PlaybackSession` object containing:
   - `id` — session ID used for all subsequent sync/close calls
   - `audioTracks` array — each with `index`, `startOffset`, `duration`, `contentUrl`, `mimeType`
   - `currentTime`, `duration`, `chapters`, `coverPath`, etc.
3. The `contentUrl` in audioTracks is a **relative path** (e.g., `/s/item/li_abc123/filename.mp3`)
   - Must prepend the server's base URL: `{server.url}{contentUrl}`
   - Must include auth: either `Authorization: Bearer` header or `?token=` query param
   - In multi-server context, always use the URL of the server that owns the session
4. Store the session ID locally — needed for sync and close calls

### AVPlayer Management
- Single `AudioPlayerService` with one shared AVPlayer instance
- Handles sequential track advancement using the `audioTracks` array from the playback session
- Streaming URL construction: `{serverBaseUrl}{track.contentUrl}?token={serverToken}`
- Offline: plays from local file URLs for downloaded books
- Background audio: AVAudioSession category `.playback`
- Interruption handling: pause on interruption, resume when ended

### Now Playing / Lock Screen / CarPlay
- `MPNowPlayingInfoCenter`: cover art, title, author, chapter name, elapsed/remaining time
- `MPRemoteCommandCenter`: play, pause, skip forward, skip back, seek, next/previous track (chapter)
- CarPlay support via remote command center (no additional CarPlay framework needed)

### Playback Speed
- Range: 0.5x to 3.0x in 0.1x increments
- Two-tier system:
  - **Global default** set in Settings (applies to any new book)
  - **Per-book override** set from Now Playing (stored in ListeningProgress.playbackSpeed)
- If per-book speed is set, changing global default does NOT affect that book
- If per-book speed is nil, global default is used

### Sleep Timer
- Options: 5, 10, 15, 30, 60 minutes, end of chapter, custom
- "End of chapter" monitors chapter boundary and pauses at transition
- Countdown displayed in Now Playing view
- Gentle fade-out over last 3 seconds before pausing

### Skip Duration
- Configurable in Settings: 10s, 15s, 30s, 45s, 60s
- Default: 30s forward, 30s back
- Applied to lock screen controls and in-app buttons

### Resume Rewind
- When resuming after being paused for **more than 2 minutes**, rewind a few seconds for context
- Configurable rewind amount: 0, 3, 5, 10 seconds
- Default: 5 seconds
- Threshold (2 min) is not user-configurable — just the rewind amount

## Progress Tracking

This is the highest-priority feature. Local-first with server sync.

### Local Source of Truth
- `ListeningProgress` in SwiftData updated every ~5 seconds during playback
- All UI reads from local progress
- `needsSync` flag marks changes that haven't been pushed to servers

### Sync Strategy
| Event | Action |
|-------|--------|
| Play start | POST `/api/items/{id}/play` to create server session |
| During playback | POST `/api/sessions/open/{id}/sync` every ~60 seconds |
| Pause / stop | Immediate sync + POST `/api/sessions/open/{id}/close` |
| App foreground | GET `/api/me/progress/{id}` from all servers, compare timestamps |
| App background | Final sync push to all servers |
| Connectivity restored | Flush all `needsSync` progress to servers |

### Conflict Resolution
- Latest timestamp wins, **but never regress position by more than 60 seconds without user confirmation**
- If local is ahead → push to server
- If server is ahead (listened on another device) → pull to local
- If server has an earlier position with a newer timestamp (e.g., re-listened on another device), show a prompt: "Your progress on [Server] is at 2:00 but you were at 5:00 locally. Use server position or keep local?"
- Multi-server: sync progress to ALL connected servers that have the book

### Offline Scenario
- Progress accumulates locally with `needsSync = true`
- When connectivity returns, sync to all servers
- If user switches servers while offline, local progress ensures continuity

## Offline Downloads

### Download Flow
1. User taps Download on book detail or Now Playing
2. DownloadService checks network: if cellular and "Download over cellular" is off → show alert, don't start
3. Queue download of all audio files from preferred server
4. Use URLSession background download tasks (survives app termination)
5. Files stored in app documents directory: `Downloads/{bookId}/{filename}`
6. Download model updated as progress advances
7. On completion, book available for offline playback

### Network Policy
- **"Download over cellular" toggle** in Settings (default: OFF)
- Monitored via NWPathMonitor
- If toggle is off and network switches to cellular mid-download → pause downloads, show notification
- Streaming is always allowed on any network (only downloads are gated)

### Storage Management
- Downloads tab shows total storage used per book and overall
- Swipe-to-delete individual book downloads
- Settings → Manage Storage: list downloads sorted by size
- Optional: auto-remove downloads after finishing a book (toggle in Settings, default off)

### Error Handling
- **Storage full mid-download:** Download moves to `failed` state, partial files cleaned up, user notified with "Not enough storage" alert and suggestion to free space
- **Network lost mid-download:** Download moves to `paused` state, auto-resumes when connectivity returns
- **Server unreachable mid-download:** Retry 3 times with exponential backoff, then move to `failed` with option to retry manually

## Navigation & Tab Structure

### Tab Bar (4 tabs)
1. **Library** — home screen, browsing
2. **Search** — search across all servers
3. **Downloads** — offline content management
4. **Settings** — servers, playback, downloads, appearance

### Mini-Player Bar
- Persistent bar above tab bar when audio is active
- Shows: cover thumbnail, title, chapter, play/pause, skip forward
- Tap to expand to full-screen Now Playing view
- Swipe down from Now Playing to collapse back to mini-player

### Library Tab
- **Continue Listening** — horizontal scroll, sorted by last listened date
- **Recently Added** — latest additions across all servers
- **All Books** — grid/list toggle, sortable by title, author, date added, duration
- Pull-to-refresh fetches latest from all servers

### Search Tab
- Queries `GET /api/libraries/{id}/search?q=` on all active servers concurrently
- Results deduplicated using same algorithm as library merging
- Search by title, author, narrator
- Recent searches saved locally

### Book Detail View
- Cover art, title, author, narrator, description, duration
- Series info with position (if applicable)
- Chapter list
- Progress bar if in progress
- Play / Download buttons
- If on multiple servers: "Available on N servers" → tap for comparison view (bitrate, format, size)

### Series Support
- Books in a series grouped in library view
- Series detail view: reading order with per-book progress
- "Next in series" prompt when finishing a book

## Visual Design

### Theme: Dark & Cinematic
- Deep blues/purples as base: `#1a1a2e`, `#16213e`, `#0f3460`
- Accent gradient: `#e94560` → `#533483` (pink-to-purple)
- Full light/dark mode support (dark is the default personality)
- System appearance option (follows iOS setting)

### Iconography
- SF Symbols throughout
- Tab bar: book (Library), magnifyingglass (Search), arrow.down.circle (Downloads), gearshape (Settings)

### Typography
- System font (San Francisco) at standard Dynamic Type sizes
- Bold titles, regular body, caption for metadata

### Now Playing Layout
- Large cover art with shadow
- Title, author below
- Chapter selector (tappable, opens chapter list)
- Scrubber with elapsed/remaining time
- Transport controls: speed, rewind 30s, play/pause, forward 30s, sleep timer
- AirPlay button top-right
- Bottom actions: Bookmark, Download, Chapters

## Audiobookshelf API Endpoints Used

| Purpose | Method | Endpoint |
|---------|--------|----------|
| Login | POST | `/login` |
| Validate token | GET | `/api/authorize` |
| List libraries | GET | `/api/libraries` |
| List library items | GET | `/api/libraries/{id}/items?limit=100&page=N` |
| Get item details | GET | `/api/items/{id}` |
| Get item cover | GET | `/api/items/{id}/cover` |
| Search library | GET | `/api/libraries/{id}/search?q=` |
| Start playback session | POST | `/api/items/{id}/play` |
| Sync session | POST | `/api/sessions/open/{id}/sync` |
| Close session | POST | `/api/sessions/open/{id}/close` |
| Get progress | GET | `/api/me/progress/{id}` |
| Update progress | PATCH | `/api/me/progress/{id}` |
| Stream audio | GET | `contentUrl` from AudioTrack objects |
| Get user info | GET | `/api/me` |
| Get listening sessions | GET | `/api/me/listening-sessions` |
| Get listening stats | GET | `/api/me/listening-stats` |

## Image Caching

- Cover art fetched via `GET /api/items/{id}/cover` (append `?token=` or auth header)
- Disk cache in app's Caches directory (system can evict when storage is low)
- Two sizes cached: thumbnail (120px, for grid/list views) and full (600px, for detail/Now Playing)
- Cache keyed by `{serverId}_{libraryItemId}` — avoids conflicts across servers
- Max cache size: 500MB, LRU eviction when exceeded
- Cache persists across launches but is not backed up to iCloud

## Out of Scope (for v1)

- Server management (adding/removing books, user management)
- Podcast support (Audiobookshelf supports podcasts, but Nimbus is audiobook-focused)
- Social features
- Widgets (future enhancement)
- watchOS companion (future enhancement)
- Accent color customization (future enhancement)
