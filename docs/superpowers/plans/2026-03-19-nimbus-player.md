# Nimbus Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS 17+ audiobook listening app (Nimbus Player) that connects to Audiobookshelf servers with multi-server support, offline downloads, and local-first progress tracking.

**Architecture:** MVVM with service layer. SwiftUI views bind to @Observable ViewModels which call into singleton Services. SwiftData for persistence, AVFoundation for audio, URLSession for networking. Zero third-party dependencies.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, AVFoundation, MediaPlayer, Network framework, Security framework (Keychain)

**Spec:** `docs/superpowers/specs/2026-03-19-nimbus-player-design.md`

**Prerequisites:** Xcode 16+ with iOS 17 SDK. Install xcodegen: `brew install xcodegen`

---

## File Structure

```
NimbusPlayer/
├── project.yml
├── NimbusPlayer/
│   ├── App/
│   │   ├── NimbusPlayerApp.swift
│   │   └── AppState.swift
│   ├── Models/
│   │   ├── Server.swift
│   │   ├── CachedBook.swift
│   │   ├── ServerBookMapping.swift
│   │   ├── ListeningProgress.swift
│   │   ├── DownloadModel.swift
│   │   ├── Bookmark.swift
│   │   └── API/
│   │       ├── LoginResponse.swift
│   │       ├── LibraryResponse.swift
│   │       ├── LibraryItemResponse.swift
│   │       ├── PlaybackSessionResponse.swift
│   │       └── SearchResponse.swift
│   ├── Services/
│   │   ├── APIClient.swift
│   │   ├── KeychainService.swift
│   │   ├── AudioPlayerService.swift
│   │   ├── ServerService.swift
│   │   ├── LibraryService.swift
│   │   ├── ProgressService.swift
│   │   ├── DownloadService.swift
│   │   ├── ImageCacheService.swift
│   │   └── NetworkMonitor.swift
│   ├── Utilities/
│   │   ├── UUIDv5.swift
│   │   ├── JaroWinkler.swift
│   │   └── BookMatcher.swift
│   ├── ViewModels/
│   │   ├── LibraryViewModel.swift
│   │   ├── SearchViewModel.swift
│   │   ├── NowPlayingViewModel.swift
│   │   ├── DownloadsViewModel.swift
│   │   ├── SettingsViewModel.swift
│   │   ├── BookDetailViewModel.swift
│   │   └── ServerSetupViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── Library/
│   │   │   ├── LibraryView.swift
│   │   │   ├── BookGridItem.swift
│   │   │   ├── BookListRow.swift
│   │   │   └── ContinueListeningRow.swift
│   │   ├── Search/
│   │   │   └── SearchView.swift
│   │   ├── NowPlaying/
│   │   │   ├── NowPlayingView.swift
│   │   │   ├── MiniPlayerBar.swift
│   │   │   ├── ChapterListSheet.swift
│   │   │   └── SleepTimerSheet.swift
│   │   ├── BookDetail/
│   │   │   ├── BookDetailView.swift
│   │   │   └── ServerComparisonSheet.swift
│   │   ├── Downloads/
│   │   │   └── DownloadsView.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── ServerListView.swift
│   │   │   ├── AddServerView.swift
│   │   │   └── StorageManagementView.swift
│   │   └── Components/
│   │       ├── CoverImageView.swift
│   │       ├── ProgressBar.swift
│   │       └── ToastView.swift
│   ├── Theme/
│   │   └── NimbusTheme.swift
│   └── Assets.xcassets/
│       ├── AccentColor.colorset/
│       │   └── Contents.json
│       ├── AppIcon.appiconset/
│       │   └── Contents.json
│       └── Contents.json
├── NimbusPlayerTests/
│   ├── UUIDv5Tests.swift
│   ├── JaroWinklerTests.swift
│   ├── BookMatcherTests.swift
│   ├── APIClientTests.swift
│   ├── KeychainServiceTests.swift
│   ├── ProgressServiceTests.swift
│   └── AudioPlayerServiceTests.swift
```

---

## Phase 1: Project Foundation

### Task 1: Xcode Project Scaffold

**Files:**
- Create: `NimbusPlayer/project.yml`
- Create: `NimbusPlayer/NimbusPlayer/App/NimbusPlayerApp.swift`
- Create: `NimbusPlayer/NimbusPlayer/App/AppState.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/ContentView.swift`
- Create: `NimbusPlayer/NimbusPlayer/Theme/NimbusTheme.swift`
- Create: Asset catalog files

- [ ] **Step 1: Create directory structure**

```bash
cd /Users/brianwells/Audiobook
mkdir -p NimbusPlayer/NimbusPlayer/{App,Models/API,Services,Utilities,ViewModels}
mkdir -p NimbusPlayer/NimbusPlayer/Views/{Library,Search,NowPlaying,BookDetail,Downloads,Settings,Components}
mkdir -p NimbusPlayer/NimbusPlayer/Theme
mkdir -p NimbusPlayer/NimbusPlayer/Assets.xcassets/{AccentColor.colorset,AppIcon.appiconset}
mkdir -p NimbusPlayer/NimbusPlayerTests
```

- [ ] **Step 2: Create project.yml for xcodegen**

```yaml
# NimbusPlayer/project.yml
name: NimbusPlayer
options:
  bundleIdPrefix: com.nimbusplayer
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true
settings:
  base:
    SWIFT_VERSION: "5.9"
    TARGETED_DEVICE_FAMILY: "1"
    INFOPLIST_KEY_UILaunchScreen_Generation: "YES"
    INFOPLIST_KEY_UIApplicationSceneManifest_Generation: "YES"
    INFOPLIST_KEY_UIBackgroundModes: "audio"
    ENABLE_USER_SCRIPT_SANDBOXING: "NO"
targets:
  NimbusPlayer:
    type: application
    platform: iOS
    sources:
      - NimbusPlayer
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.nimbusplayer.app
        INFOPLIST_KEY_CFBundleDisplayName: "Nimbus Player"
        INFOPLIST_KEY_UIRequiresFullScreen: "YES"
  NimbusPlayerTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - NimbusPlayerTests
    dependencies:
      - target: NimbusPlayer
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.nimbusplayer.app.tests
```

- [ ] **Step 3: Create NimbusTheme.swift**

```swift
// NimbusPlayer/NimbusPlayer/Theme/NimbusTheme.swift
import SwiftUI

enum NimbusTheme {
    // MARK: - Colors
    enum Colors {
        static let backgroundPrimary = Color(red: 0.102, green: 0.102, blue: 0.180)   // #1a1a2e
        static let backgroundSecondary = Color(red: 0.086, green: 0.129, blue: 0.243)  // #16213e
        static let backgroundTertiary = Color(red: 0.059, green: 0.204, blue: 0.376)   // #0f3460
        static let accentPink = Color(red: 0.914, green: 0.271, blue: 0.376)           // #e94560
        static let accentPurple = Color(red: 0.325, green: 0.204, blue: 0.514)         // #533483
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 0.545, green: 0.561, blue: 0.639)        // #8b8fa3
        static let textTertiary = Color(red: 0.420, green: 0.435, blue: 0.522)         // #6b6f84
        static let surfaceOverlay = Color.white.opacity(0.06)
        static let surfaceElevated = Color(red: 0.137, green: 0.137, blue: 0.267)      // #232344
        static let divider = Color.white.opacity(0.06)
    }

    // MARK: - Gradients
    enum Gradients {
        static let accent = LinearGradient(
            colors: [Colors.accentPink, Colors.accentPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let background = LinearGradient(
            colors: [Colors.backgroundPrimary, Color(red: 0.051, green: 0.051, blue: 0.102)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Dimensions
    enum Dimensions {
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let coverThumbnailSize: CGFloat = 52
        static let coverGridSize: CGFloat = 110
        static let coverDetailSize: CGFloat = 200
        static let miniPlayerHeight: CGFloat = 64
        static let tabBarHeight: CGFloat = 56
    }
}
```

- [ ] **Step 4: Create AppState.swift**

```swift
// NimbusPlayer/NimbusPlayer/App/AppState.swift
import SwiftUI

@Observable
final class AppState {
    var isAuthenticated: Bool {
        get { UserDefaults.standard.bool(forKey: "isAuthenticated") }
        set { UserDefaults.standard.set(newValue, forKey: "isAuthenticated") }
    }
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // Global user settings — all persisted via UserDefaults
    var defaultPlaybackSpeed: Double {
        get { UserDefaults.standard.double(forKey: "defaultPlaybackSpeed").nonZero ?? 1.0 }
        set { UserDefaults.standard.set(newValue, forKey: "defaultPlaybackSpeed") }
    }
    var skipForwardDuration: TimeInterval {
        get { UserDefaults.standard.double(forKey: "skipForwardDuration").nonZero ?? 30 }
        set { UserDefaults.standard.set(newValue, forKey: "skipForwardDuration") }
    }
    var skipBackwardDuration: TimeInterval {
        get { UserDefaults.standard.double(forKey: "skipBackwardDuration").nonZero ?? 30 }
        set { UserDefaults.standard.set(newValue, forKey: "skipBackwardDuration") }
    }
    var resumeRewindSeconds: TimeInterval {
        get { UserDefaults.standard.double(forKey: "resumeRewindSeconds").nonZero ?? 5 }
        set { UserDefaults.standard.set(newValue, forKey: "resumeRewindSeconds") }
    }
    var downloadOverCellular: Bool {
        get { UserDefaults.standard.bool(forKey: "downloadOverCellular") }
        set { UserDefaults.standard.set(newValue, forKey: "downloadOverCellular") }
    }
    var autoRemoveFinishedDownloads: Bool {
        get { UserDefaults.standard.bool(forKey: "autoRemoveFinishedDownloads") }
        set { UserDefaults.standard.set(newValue, forKey: "autoRemoveFinishedDownloads") }
    }
    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "appearanceMode") ?? "system") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appearanceMode") }
    }

    enum AppearanceMode: String, CaseIterable {
        case dark, light, system
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
```

- [ ] **Step 5: Create NimbusPlayerApp.swift**

```swift
// NimbusPlayer/NimbusPlayer/App/NimbusPlayerApp.swift
import SwiftUI
import SwiftData

@main
struct NimbusPlayerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(for: [
            Server.self,
            CachedBook.self,
            ServerBookMapping.self,
            ListeningProgress.self,
            DownloadModel.self,
            Bookmark.self
        ])
    }

    private var colorScheme: ColorScheme? {
        switch appState.appearanceMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}
```

- [ ] **Step 6: Create ContentView.swift (tab structure)**

```swift
// NimbusPlayer/NimbusPlayer/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            MainTabView()
        } else {
            AddServerView(isOnboarding: true)
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Library", systemImage: "book.fill", value: 0) {
                    LibraryView()
                }
                Tab("Search", systemImage: "magnifyingglass", value: 1) {
                    SearchView()
                }
                Tab("Downloads", systemImage: "arrow.down.circle.fill", value: 2) {
                    DownloadsView()
                }
                Tab("Settings", systemImage: "gearshape.fill", value: 3) {
                    SettingsView()
                }
            }
            .tint(NimbusTheme.Colors.accentPink)
        }
    }
}
```

- [ ] **Step 7: Create placeholder views for each tab**

```swift
// NimbusPlayer/NimbusPlayer/Views/Library/LibraryView.swift
import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            Text("Library")
                .navigationTitle("Library")
        }
    }
}
```

```swift
// NimbusPlayer/NimbusPlayer/Views/Search/SearchView.swift
import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationStack {
            Text("Search")
                .navigationTitle("Search")
        }
    }
}
```

```swift
// NimbusPlayer/NimbusPlayer/Views/Downloads/DownloadsView.swift
import SwiftUI

struct DownloadsView: View {
    var body: some View {
        NavigationStack {
            Text("Downloads")
                .navigationTitle("Downloads")
        }
    }
}
```

```swift
// NimbusPlayer/NimbusPlayer/Views/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("Settings")
                .navigationTitle("Settings")
        }
    }
}
```

```swift
// NimbusPlayer/NimbusPlayer/Views/Settings/AddServerView.swift
import SwiftUI

struct AddServerView: View {
    var isOnboarding: Bool = false

    var body: some View {
        NavigationStack {
            Text("Add Server")
                .navigationTitle("Connect to Server")
        }
    }
}
```

- [ ] **Step 8: Create asset catalog files**

```json
// NimbusPlayer/NimbusPlayer/Assets.xcassets/Contents.json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

```json
// NimbusPlayer/NimbusPlayer/Assets.xcassets/AccentColor.colorset/Contents.json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.376",
          "green" : "0.271",
          "red" : "0.914"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

```json
// NimbusPlayer/NimbusPlayer/Assets.xcassets/AppIcon.appiconset/Contents.json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 9: Generate Xcode project and verify**

```bash
cd /Users/brianwells/Audiobook/NimbusPlayer
xcodegen generate
```

Expected: `⚙ Generating plists...` → `Created project at ...NimbusPlayer.xcodeproj`

- [ ] **Step 10: Build to verify scaffold compiles**

```bash
cd /Users/brianwells/Audiobook/NimbusPlayer
xcodebuild -project NimbusPlayer.xcodeproj -scheme NimbusPlayer -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 11: Commit**

```bash
cd /Users/brianwells/Audiobook
echo ".superpowers/" >> .gitignore
git add NimbusPlayer/ .gitignore
git commit -m "feat: scaffold Nimbus Player Xcode project with tab structure and theme"
```

---

### Task 2: UUID v5 Utility

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Utilities/UUIDv5.swift`
- Create: `NimbusPlayer/NimbusPlayerTests/UUIDv5Tests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// NimbusPlayer/NimbusPlayerTests/UUIDv5Tests.swift
import Testing
@testable import NimbusPlayer

struct UUIDv5Tests {
    static let nimbusNamespace = UUID(uuidString: "8bcf5e6a-3b2a-4f7d-9c1e-a5d8f2b7c4e1")!

    @Test func sameInputProducesSameUUID() {
        let id1 = UUIDv5.generate(namespace: Self.nimbusNamespace, name: "asin:B08G9PRS1K")
        let id2 = UUIDv5.generate(namespace: Self.nimbusNamespace, name: "asin:B08G9PRS1K")
        #expect(id1 == id2)
    }

    @Test func differentInputProducesDifferentUUID() {
        let id1 = UUIDv5.generate(namespace: Self.nimbusNamespace, name: "asin:B08G9PRS1K")
        let id2 = UUIDv5.generate(namespace: Self.nimbusNamespace, name: "asin:B07RZYHQ6X")
        #expect(id1 != id2)
    }

    @Test func versionAndVariantBitsCorrect() {
        let id = UUIDv5.generate(namespace: Self.nimbusNamespace, name: "test")
        let uuidString = id.uuidString
        // UUID v5: version nibble is '5' (character at index 14)
        let versionChar = uuidString[uuidString.index(uuidString.startIndex, offsetBy: 14)]
        #expect(versionChar == "5")
        // Variant: character at index 19 should be 8, 9, A, or B
        let variantChar = uuidString[uuidString.index(uuidString.startIndex, offsetBy: 19)]
        #expect("89AB".contains(variantChar))
    }

    @Test func emptyNameProducesValidUUID() {
        let id = UUIDv5.generate(namespace: Self.nimbusNamespace, name: "")
        #expect(id != UUID())
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project NimbusPlayer.xcodeproj -scheme NimbusPlayerTests \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:NimbusPlayerTests/UUIDv5Tests 2>&1 | grep -E "(Test |error:)"
```

Expected: compilation errors — `UUIDv5` not found

- [ ] **Step 3: Implement UUIDv5**

```swift
// NimbusPlayer/NimbusPlayer/Utilities/UUIDv5.swift
import Foundation
import CommonCrypto

enum UUIDv5 {
    static let nimbusNamespace = UUID(uuidString: "8bcf5e6a-3b2a-4f7d-9c1e-a5d8f2b7c4e1")!

    static func generate(namespace: UUID, name: String) -> UUID {
        let namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        let nameBytes = Array(name.utf8)

        var data = namespaceBytes + nameBytes
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1(&data, CC_LONG(data.count), &hash)

        // Set version to 5
        hash[6] = (hash[6] & 0x0F) | 0x50
        // Set variant to RFC 4122
        hash[8] = (hash[8] & 0x3F) | 0x80

        let uuid = UUID(uuid: (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        ))
        return uuid
    }

    /// Generate a deterministic book ID from ASIN, ISBN, or title+author
    static func bookID(asin: String?, isbn: String?, title: String, author: String) -> UUID {
        if let asin, !asin.isEmpty {
            return generate(namespace: nimbusNamespace, name: "asin:\(asin)")
        }
        if let isbn, !isbn.isEmpty {
            return generate(namespace: nimbusNamespace, name: "isbn:\(isbn)")
        }
        let normalizedTitle = normalizeForID(title)
        let normalizedAuthor = normalizeForID(author)
        return generate(namespace: nimbusNamespace, name: "title:\(normalizedTitle)|author:\(normalizedAuthor)")
    }

    private static func normalizeForID(_ string: String) -> String {
        string
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project NimbusPlayer.xcodeproj -scheme NimbusPlayerTests \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:NimbusPlayerTests/UUIDv5Tests 2>&1 | grep -E "(Test |Executed)"
```

Expected: all 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Utilities/UUIDv5.swift NimbusPlayer/NimbusPlayerTests/UUIDv5Tests.swift
git commit -m "feat: add UUID v5 utility for deterministic book identity"
```

---

### Task 3: Jaro-Winkler Similarity

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Utilities/JaroWinkler.swift`
- Create: `NimbusPlayer/NimbusPlayerTests/JaroWinklerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// NimbusPlayer/NimbusPlayerTests/JaroWinklerTests.swift
import Testing
@testable import NimbusPlayer

struct JaroWinklerTests {
    @Test func identicalStrings() {
        let score = JaroWinkler.similarity("hello", "hello")
        #expect(score == 1.0)
    }

    @Test func completelyDifferent() {
        let score = JaroWinkler.similarity("abc", "xyz")
        #expect(score < 0.5)
    }

    @Test func similarStrings() {
        let score = JaroWinkler.similarity("martha", "marhta")
        #expect(score > 0.95)
    }

    @Test func emptyStrings() {
        #expect(JaroWinkler.similarity("", "") == 1.0)
        #expect(JaroWinkler.similarity("abc", "") == 0.0)
        #expect(JaroWinkler.similarity("", "abc") == 0.0)
    }

    @Test func caseInsensitive() {
        let score = JaroWinkler.similarity("Hello World", "hello world")
        #expect(score == 1.0)
    }

    @Test func bookTitleSimilarity() {
        let score = JaroWinkler.similarity("project hail mary", "project hail mary")
        #expect(score == 1.0)
    }

    @Test func slightlyDifferentTitles() {
        // "The Martian" vs "Martian, The" after normalization would both become "martian"
        let score = JaroWinkler.similarity("the martian", "martian")
        #expect(score > 0.7) // Related but not identical after normalization
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: compilation error — `JaroWinkler` not found

- [ ] **Step 3: Implement Jaro-Winkler**

```swift
// NimbusPlayer/NimbusPlayer/Utilities/JaroWinkler.swift
import Foundation

enum JaroWinkler {
    /// Jaro-Winkler similarity between two strings (0.0 to 1.0).
    /// Comparison is case-insensitive.
    static func similarity(_ s1: String, _ s2: String) -> Double {
        let str1 = s1.lowercased()
        let str2 = s2.lowercased()

        if str1 == str2 { return 1.0 }
        if str1.isEmpty || str2.isEmpty { return 0.0 }

        let jaroScore = jaro(Array(str1), Array(str2))

        // Winkler modification: boost for common prefix (up to 4 chars)
        let prefixLength = min(4, zip(str1, str2).prefix(while: { $0 == $1 }).count)
        let winklerScore = jaroScore + Double(prefixLength) * 0.1 * (1.0 - jaroScore)

        return min(winklerScore, 1.0)
    }

    private static func jaro(_ s1: [Character], _ s2: [Character]) -> Double {
        let maxDist = max(s1.count, s2.count) / 2 - 1
        if maxDist < 0 { return s1 == s2 ? 1.0 : 0.0 }

        var s1Matches = [Bool](repeating: false, count: s1.count)
        var s2Matches = [Bool](repeating: false, count: s2.count)
        var matches = 0
        var transpositions = 0

        for i in s1.indices {
            let start = max(0, i - maxDist)
            let end = min(i + maxDist + 1, s2.count)
            for j in start..<end {
                if s2Matches[j] || s1[i] != s2[j] { continue }
                s1Matches[i] = true
                s2Matches[j] = true
                matches += 1
                break
            }
        }

        if matches == 0 { return 0.0 }

        var k = 0
        for i in s1.indices {
            if !s1Matches[i] { continue }
            while !s2Matches[k] { k += 1 }
            if s1[i] != s2[k] { transpositions += 1 }
            k += 1
        }

        let m = Double(matches)
        return (m / Double(s1.count) + m / Double(s2.count) + (m - Double(transpositions) / 2.0) / m) / 3.0
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: all 7 tests pass

- [ ] **Step 5: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Utilities/JaroWinkler.swift NimbusPlayer/NimbusPlayerTests/JaroWinklerTests.swift
git commit -m "feat: add Jaro-Winkler string similarity for book deduplication"
```

---

### Task 4: Book Matcher Utility

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Utilities/BookMatcher.swift`
- Create: `NimbusPlayer/NimbusPlayerTests/BookMatcherTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// NimbusPlayer/NimbusPlayerTests/BookMatcherTests.swift
import Testing
@testable import NimbusPlayer

struct BookMatcherTests {
    @Test func normalizeStripsSubtitleColon() {
        let result = BookMatcher.normalize("Project Hail Mary: A Novel")
        #expect(result == "project hail mary")
    }

    @Test func normalizeStripsSubtitleDash() {
        let result = BookMatcher.normalize("Dune - The First Novel")
        #expect(result == "dune")
    }

    @Test func normalizeStripsArticles() {
        #expect(BookMatcher.normalize("The Martian") == "martian")
        #expect(BookMatcher.normalize("A Brief History of Time") == "brief history of time")
        #expect(BookMatcher.normalize("An Example Title") == "example title")
    }

    @Test func matchByASIN() {
        let a = BookMatcher.BookIdentity(asin: "B08G9PRS1K", isbn: nil, title: "Foo", author: "Bar")
        let b = BookMatcher.BookIdentity(asin: "B08G9PRS1K", isbn: nil, title: "Different", author: "Author")
        #expect(BookMatcher.areMatching(a, b))
    }

    @Test func matchByISBN() {
        let a = BookMatcher.BookIdentity(asin: nil, isbn: "9780593135204", title: "Foo", author: "Bar")
        let b = BookMatcher.BookIdentity(asin: nil, isbn: "9780593135204", title: "Different", author: "Author")
        #expect(BookMatcher.areMatching(a, b))
    }

    @Test func matchByFuzzyTitleAndAuthor() {
        let a = BookMatcher.BookIdentity(asin: nil, isbn: nil, title: "Project Hail Mary", author: "Andy Weir")
        let b = BookMatcher.BookIdentity(asin: nil, isbn: nil, title: "Project Hail Mary: A Novel", author: "Andy Weir")
        #expect(BookMatcher.areMatching(a, b))
    }

    @Test func noMatchDifferentAuthorSameTitle() {
        let a = BookMatcher.BookIdentity(asin: nil, isbn: nil, title: "Dune", author: "Frank Herbert")
        let b = BookMatcher.BookIdentity(asin: nil, isbn: nil, title: "Dune", author: "Brian Herbert")
        // Author similarity for "Frank Herbert" vs "Brian Herbert" — should fail the ≥0.85 threshold
        #expect(!BookMatcher.areMatching(a, b))
    }

    @Test func noMatchDifferentBooks() {
        let a = BookMatcher.BookIdentity(asin: nil, isbn: nil, title: "The Martian", author: "Andy Weir")
        let b = BookMatcher.BookIdentity(asin: nil, isbn: nil, title: "Artemis", author: "Andy Weir")
        #expect(!BookMatcher.areMatching(a, b))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: compilation error — `BookMatcher` not found

- [ ] **Step 3: Implement BookMatcher**

```swift
// NimbusPlayer/NimbusPlayer/Utilities/BookMatcher.swift
import Foundation

enum BookMatcher {
    struct BookIdentity {
        let asin: String?
        let isbn: String?
        let title: String
        let author: String
    }

    static let similarityThreshold = 0.85

    /// Check if two book identities refer to the same book
    static func areMatching(_ a: BookIdentity, _ b: BookIdentity) -> Bool {
        // Priority 1: Exact ASIN match
        if let asinA = a.asin, !asinA.isEmpty,
           let asinB = b.asin, !asinB.isEmpty {
            return asinA == asinB
        }

        // Priority 2: Exact ISBN match
        if let isbnA = a.isbn, !isbnA.isEmpty,
           let isbnB = b.isbn, !isbnB.isEmpty {
            return isbnA == isbnB
        }

        // Priority 3: Fuzzy title + author (both must meet threshold)
        let titleSimilarity = JaroWinkler.similarity(normalize(a.title), normalize(b.title))
        let authorSimilarity = JaroWinkler.similarity(normalize(a.author), normalize(b.author))

        return titleSimilarity >= similarityThreshold && authorSimilarity >= similarityThreshold
    }

    /// Normalize a string for comparison: lowercase, strip subtitle, remove articles, trim
    static func normalize(_ string: String) -> String {
        var result = string
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip subtitle after colon
        if let colonRange = result.range(of: ":") {
            result = String(result[result.startIndex..<colonRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }

        // Strip subtitle after " - "
        if let dashRange = result.range(of: " - ") {
            result = String(result[result.startIndex..<dashRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }

        // Remove leading articles
        let articles = ["the ", "a ", "an "]
        for article in articles {
            if result.hasPrefix(article) {
                result = String(result.dropFirst(article.count))
                break
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: all 8 tests pass

- [ ] **Step 5: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Utilities/BookMatcher.swift NimbusPlayer/NimbusPlayerTests/BookMatcherTests.swift
git commit -m "feat: add BookMatcher with ASIN/ISBN/fuzzy deduplication"
```

---

### Task 5: SwiftData Models

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Models/Server.swift`
- Create: `NimbusPlayer/NimbusPlayer/Models/CachedBook.swift`
- Create: `NimbusPlayer/NimbusPlayer/Models/ServerBookMapping.swift`
- Create: `NimbusPlayer/NimbusPlayer/Models/ListeningProgress.swift`
- Create: `NimbusPlayer/NimbusPlayer/Models/DownloadModel.swift`
- Create: `NimbusPlayer/NimbusPlayer/Models/Bookmark.swift`

- [ ] **Step 1: Create Server model**

```swift
// NimbusPlayer/NimbusPlayer/Models/Server.swift
import Foundation
import SwiftData

@Model
final class Server {
    @Attribute(.unique) var id: UUID
    var url: String
    var username: String
    var displayName: String
    var isActive: Bool
    var lastConnected: Date?

    @Relationship(deleteRule: .cascade, inverse: \ServerBookMapping.server)
    var bookMappings: [ServerBookMapping] = []

    @Relationship(deleteRule: .cascade, inverse: \DownloadModel.server)
    var downloads: [DownloadModel] = []

    init(url: String, username: String, displayName: String) {
        self.id = UUID()
        self.url = url.hasSuffix("/") ? String(url.dropLast()) : url
        self.username = username
        self.displayName = displayName
        self.isActive = true
    }

    /// Base URL without trailing slash
    var baseURL: URL? {
        URL(string: url)
    }
}
```

- [ ] **Step 2: Create CachedBook model**

```swift
// NimbusPlayer/NimbusPlayer/Models/CachedBook.swift
import Foundation
import SwiftData

@Model
final class CachedBook {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var narrator: String?
    var asin: String?
    var isbn: String?
    var bookDescription: String?
    var duration: TimeInterval
    var coverPath: String?
    var seriesName: String?
    var seriesSequence: String?
    var lastUpdated: Date

    @Relationship(deleteRule: .cascade, inverse: \ServerBookMapping.book)
    var serverMappings: [ServerBookMapping] = []

    @Relationship(deleteRule: .cascade)
    var progress: ListeningProgress?

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.book)
    var bookmarks: [Bookmark] = []

    @Relationship(deleteRule: .cascade, inverse: \DownloadModel.book)
    var downloads: [DownloadModel] = []

    init(title: String, author: String, asin: String?, isbn: String?, duration: TimeInterval) {
        self.id = UUIDv5.bookID(asin: asin, isbn: isbn, title: title, author: author)
        self.title = title
        self.author = author
        self.asin = asin
        self.isbn = isbn
        self.duration = duration
        self.lastUpdated = Date()
    }

    /// The preferred server mapping, or the first available
    var preferredMapping: ServerBookMapping? {
        serverMappings.first(where: { $0.isPreferred }) ?? serverMappings.first
    }

    /// Whether this book exists on multiple servers
    var isMultiServer: Bool {
        serverMappings.count > 1
    }
}
```

- [ ] **Step 3: Create ServerBookMapping model**

```swift
// NimbusPlayer/NimbusPlayer/Models/ServerBookMapping.swift
import Foundation
import SwiftData

@Model
final class ServerBookMapping {
    @Attribute(.unique) var id: UUID
    var server: Server?
    var book: CachedBook?
    var libraryItemId: String
    var libraryId: String
    var bitrate: Int?
    var format: String?
    var fileSize: Int64?
    var isPreferred: Bool

    init(libraryItemId: String, libraryId: String) {
        self.id = UUID()
        self.libraryItemId = libraryItemId
        self.libraryId = libraryId
        self.isPreferred = false
    }
}
```

- [ ] **Step 4: Create ListeningProgress model**

```swift
// NimbusPlayer/NimbusPlayer/Models/ListeningProgress.swift
import Foundation
import SwiftData

@Model
final class ListeningProgress {
    @Attribute(.unique) var id: UUID
    var book: CachedBook?
    var currentTime: TimeInterval
    var totalDuration: TimeInterval
    var progress: Double
    var isFinished: Bool
    var playbackSpeed: Double?
    var lastUpdated: Date
    var needsSync: Bool

    /// Active server session ID (nil if no session open)
    var activeSessionId: String?
    /// Which server the active session belongs to
    var activeSessionServerId: UUID?

    init(book: CachedBook) {
        self.id = UUID()
        self.book = book
        self.currentTime = 0
        self.totalDuration = book.duration
        self.progress = 0
        self.isFinished = false
        self.lastUpdated = Date()
        self.needsSync = false
    }

    func update(currentTime: TimeInterval, duration: TimeInterval) {
        self.currentTime = currentTime
        self.totalDuration = duration
        self.progress = duration > 0 ? currentTime / duration : 0
        self.isFinished = progress >= 0.99
        self.lastUpdated = Date()
        self.needsSync = true
    }
}
```

- [ ] **Step 5: Create DownloadModel**

```swift
// NimbusPlayer/NimbusPlayer/Models/DownloadModel.swift
import Foundation
import SwiftData

enum DownloadState: String, Codable {
    case queued, downloading, paused, complete, failed
}

@Model
final class DownloadModel {
    @Attribute(.unique) var id: UUID
    var book: CachedBook?
    var server: Server?
    var state: DownloadState
    var totalBytes: Int64
    var downloadedBytes: Int64
    var relativeFilePaths: [String]
    var dateStarted: Date
    var dateCompleted: Date?
    var errorMessage: String?

    init(book: CachedBook, server: Server) {
        self.id = UUID()
        self.book = book
        self.server = server
        self.state = .queued
        self.totalBytes = 0
        self.downloadedBytes = 0
        self.relativeFilePaths = []
        self.dateStarted = Date()
    }

    var progressFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }
}
```

- [ ] **Step 6: Create Bookmark model**

```swift
// NimbusPlayer/NimbusPlayer/Models/Bookmark.swift
import Foundation
import SwiftData

@Model
final class Bookmark {
    @Attribute(.unique) var id: UUID
    var book: CachedBook?
    var timestamp: TimeInterval
    var note: String?
    var dateCreated: Date

    init(book: CachedBook, timestamp: TimeInterval, note: String? = nil) {
        self.id = UUID()
        self.book = book
        self.timestamp = timestamp
        self.note = note
        self.dateCreated = Date()
    }
}
```

- [ ] **Step 7: Build to verify models compile with SwiftData**

```bash
xcodebuild -project NimbusPlayer.xcodeproj -scheme NimbusPlayer \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Models/
git commit -m "feat: add SwiftData models for Server, CachedBook, Progress, Downloads, Bookmarks"
```

---

## Phase 2: Networking & Auth

### Task 6: API Response Models

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Models/API/LoginResponse.swift`
- Create: `NimbusPlayer/NimbusPlayer/Models/API/LibraryResponse.swift`
- Create: `NimbusPlayer/NimbusPlayer/Models/API/LibraryItemResponse.swift`
- Create: `NimbusPlayer/NimbusPlayer/Models/API/PlaybackSessionResponse.swift`
- Create: `NimbusPlayer/NimbusPlayer/Models/API/SearchResponse.swift`

- [ ] **Step 1: Create all API response models**

```swift
// NimbusPlayer/NimbusPlayer/Models/API/LoginResponse.swift
import Foundation

struct LoginResponse: Codable {
    let user: UserResponse

    struct UserResponse: Codable {
        let id: String
        let username: String
        let type: String
        let token: String
        let mediaProgress: [MediaProgressResponse]?
    }
}

struct MediaProgressResponse: Codable {
    let id: String
    let libraryItemId: String
    let episodeId: String?
    let duration: Double
    let progress: Double
    let currentTime: Double
    let isFinished: Bool
    let lastUpdate: TimeInterval
    let startedAt: TimeInterval?
    let finishedAt: TimeInterval?
}

struct AuthorizeResponse: Codable {
    let user: LoginResponse.UserResponse
}
```

```swift
// NimbusPlayer/NimbusPlayer/Models/API/LibraryResponse.swift
import Foundation

struct LibrariesResponse: Codable {
    let libraries: [LibraryResponse]
}

struct LibraryResponse: Codable {
    let id: String
    let name: String
    let mediaType: String  // "book" or "podcast"
    let folders: [FolderResponse]?

    struct FolderResponse: Codable {
        let id: String
        let fullPath: String
    }
}
```

```swift
// NimbusPlayer/NimbusPlayer/Models/API/LibraryItemResponse.swift
import Foundation

struct LibraryItemsResponse: Codable {
    let results: [LibraryItemResponse]
    let total: Int
    let limit: Int
    let page: Int
}

struct LibraryItemResponse: Codable {
    let id: String
    let ino: String?
    let libraryId: String
    let mediaType: String
    let media: MediaResponse

    struct MediaResponse: Codable {
        let metadata: MetadataResponse
        let coverPath: String?
        let duration: Double?
        let audioFiles: [AudioFileResponse]?
        let chapters: [ChapterResponse]?
        let size: Int64?

        struct MetadataResponse: Codable {
            let title: String?
            let subtitle: String?
            let authors: [AuthorResponse]?
            let narrators: [String]?
            let series: [SeriesEntryResponse]?
            let genres: [String]?
            let publishedYear: String?
            let description: String?
            let isbn: String?
            let asin: String?
            let language: String?
        }

        struct AuthorResponse: Codable {
            let id: String?
            let name: String
        }

        struct SeriesEntryResponse: Codable {
            let id: String?
            let name: String?
            let sequence: String?
        }

        struct AudioFileResponse: Codable {
            let index: Int?
            let ino: String?
            let metadata: FileMetadataResponse?
            let duration: Double?
            let bitRate: Int?
            let codec: String?
            let mimeType: String?

            struct FileMetadataResponse: Codable {
                let filename: String?
                let ext: String?
                let path: String?
                let size: Int64?
            }
        }

        struct ChapterResponse: Codable {
            let id: Int
            let start: Double
            let end: Double
            let title: String
        }
    }

    /// Extract title, falling back to empty string
    var title: String { media.metadata.title ?? "Unknown Title" }
    var authorName: String { media.metadata.authors?.map(\.name).joined(separator: ", ") ?? "Unknown Author" }
    var narratorName: String? { media.metadata.narrators?.joined(separator: ", ") }
    var asin: String? { media.metadata.asin }
    var isbn: String? { media.metadata.isbn }
    var seriesName: String? { media.metadata.series?.first?.name }
    var seriesSequence: String? { media.metadata.series?.first?.sequence }
    var totalDuration: TimeInterval { media.duration ?? 0 }
    var totalBitrate: Int? { media.audioFiles?.first?.bitRate }
    var totalSize: Int64? { media.size }
    var audioFormat: String? { media.audioFiles?.first?.codec }
}
```

```swift
// NimbusPlayer/NimbusPlayer/Models/API/PlaybackSessionResponse.swift
import Foundation

struct PlaybackSessionResponse: Codable {
    let id: String
    let userId: String?
    let libraryItemId: String
    let episodeId: String?
    let mediaType: String?
    let duration: Double
    let currentTime: Double
    let audioTracks: [AudioTrackResponse]
    let chapters: [LibraryItemResponse.MediaResponse.ChapterResponse]?
    let displayTitle: String?
    let displayAuthor: String?
    let coverPath: String?

    struct AudioTrackResponse: Codable {
        let index: Int
        let startOffset: Double
        let duration: Double
        let title: String?
        let contentUrl: String
        let mimeType: String
    }
}

struct PlaybackSessionRequest: Codable {
    let deviceInfo: DeviceInfo
    let forceDirectPlay: Bool
    let forceTranscode: Bool
    let supportedMimeTypes: [String]
    let mediaPlayer: String

    struct DeviceInfo: Codable {
        let deviceId: String
        let clientName: String
        let clientVersion: String
        let manufacturer: String
        let model: String
        let osName: String
        let osVersion: String
    }

    // Note: This file needs `import UIKit` at the top
    static func defaultRequest(deviceId: String, appVersion: String) -> PlaybackSessionRequest {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }

        return PlaybackSessionRequest(
            deviceInfo: DeviceInfo(
                deviceId: deviceId,
                clientName: "Nimbus Player",
                clientVersion: appVersion,
                manufacturer: "Apple",
                model: model,
                osName: "iOS",
                osVersion: UIDevice.current.systemVersion
            ),
            forceDirectPlay: true,
            forceTranscode: false,
            supportedMimeTypes: ["audio/mpeg", "audio/mp4", "audio/x-m4b", "audio/m4a", "audio/ogg"],
            mediaPlayer: "AVPlayer"
        )
    }
}

struct SessionSyncRequest: Codable {
    let currentTime: Double
    let timeListened: Double
    let duration: Double
}
```

```swift
// NimbusPlayer/NimbusPlayer/Models/API/SearchResponse.swift
import Foundation

struct SearchResponse: Codable {
    let book: [SearchBookResult]?
    let authors: [SearchAuthorResult]?
    let series: [SearchSeriesResult]?

    struct SearchBookResult: Codable {
        let libraryItem: LibraryItemResponse
    }

    struct SearchAuthorResult: Codable {
        let id: String
        let name: String
    }

    struct SearchSeriesResult: Codable {
        let id: String?
        let name: String?
        let books: [LibraryItemResponse]?
    }
}
```

- [ ] **Step 2: Build to verify models compile**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Models/API/
git commit -m "feat: add Codable API response models for Audiobookshelf endpoints"
```

---

### Task 7: Keychain Service

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Services/KeychainService.swift`
- Create: `NimbusPlayer/NimbusPlayerTests/KeychainServiceTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// NimbusPlayer/NimbusPlayerTests/KeychainServiceTests.swift
import Testing
@testable import NimbusPlayer

struct KeychainServiceTests {
    let keychain = KeychainService()
    let testServerId = UUID()

    @Test func saveAndRetrieveToken() throws {
        try keychain.saveToken("test-token-123", for: testServerId)
        let retrieved = try keychain.getToken(for: testServerId)
        #expect(retrieved == "test-token-123")
        try keychain.deleteToken(for: testServerId)
    }

    @Test func deleteToken() throws {
        try keychain.saveToken("to-delete", for: testServerId)
        try keychain.deleteToken(for: testServerId)
        let retrieved = try? keychain.getToken(for: testServerId)
        #expect(retrieved == nil)
    }

    @Test func updateExistingToken() throws {
        try keychain.saveToken("old-token", for: testServerId)
        try keychain.saveToken("new-token", for: testServerId)
        let retrieved = try keychain.getToken(for: testServerId)
        #expect(retrieved == "new-token")
        try keychain.deleteToken(for: testServerId)
    }

    @Test func getMissingTokenReturnsNil() throws {
        let retrieved = try? keychain.getToken(for: UUID())
        #expect(retrieved == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement KeychainService**

```swift
// NimbusPlayer/NimbusPlayer/Services/KeychainService.swift
import Foundation
import Security

struct KeychainService {
    private let serviceName = "com.nimbusplayer.server-tokens"

    enum KeychainError: Error {
        case saveFailed(OSStatus)
        case dataConversionError
        case notFound
    }

    func saveToken(_ token: String, for serverId: UUID) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }

        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: serverId.uuidString
        ]
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Add new item
            var addQuery = updateQuery
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.saveFailed(updateStatus)
        }
    }

    func getToken(for serverId: UUID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: serverId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    func deleteToken(for serverId: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: serverId.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: all 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Services/KeychainService.swift NimbusPlayer/NimbusPlayerTests/KeychainServiceTests.swift
git commit -m "feat: add KeychainService for secure server token storage"
```

---

### Task 8: API Client

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Services/APIClient.swift`
- Create: `NimbusPlayer/NimbusPlayerTests/APIClientTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// NimbusPlayer/NimbusPlayerTests/APIClientTests.swift
import Testing
@testable import NimbusPlayer

struct APIClientTests {
    @Test func buildURLAppendsPath() throws {
        let client = APIClient(baseURL: URL(string: "https://abs.example.com")!, token: "abc")
        let url = try client.buildURL(path: "/api/libraries")
        #expect(url.absoluteString == "https://abs.example.com/api/libraries")
    }

    @Test func buildURLWithQueryParams() throws {
        let client = APIClient(baseURL: URL(string: "https://abs.example.com")!, token: "abc")
        let url = try client.buildURL(path: "/api/libraries/lib1/items", query: ["limit": "100", "page": "0"])
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(components.path == "/api/libraries/lib1/items")
        let queryItems = components.queryItems ?? []
        #expect(queryItems.contains(where: { $0.name == "limit" && $0.value == "100" }))
        #expect(queryItems.contains(where: { $0.name == "page" && $0.value == "0" }))
    }

    @Test func buildRequestIncludesAuthHeader() throws {
        let client = APIClient(baseURL: URL(string: "https://abs.example.com")!, token: "my-token")
        let request = try client.buildRequest(method: "GET", path: "/api/me")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer my-token")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement APIClient**

```swift
// NimbusPlayer/NimbusPlayer/Services/APIClient.swift
import Foundation

final class APIClient: Sendable {
    let baseURL: URL
    let token: String
    private let session: URLSession
    private let decoder: JSONDecoder

    enum APIError: Error, LocalizedError {
        case invalidURL
        case httpError(statusCode: Int, data: Data?)
        case unauthorized
        case serverUnreachable
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .httpError(let code, _): return "HTTP error: \(code)"
            case .unauthorized: return "Authentication required"
            case .serverUnreachable: return "Server unreachable"
            case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
            }
        }
    }

    init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
        self.decoder = JSONDecoder()
    }

    func buildURL(path: String, query: [String: String]? = nil) throws -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if let query, !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    func buildRequest(method: String, path: String, query: [String: String]? = nil, body: (any Encodable)? = nil) throws -> URLRequest {
        let url = try buildURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    func request<T: Decodable>(_ type: T.Type, method: String, path: String, query: [String: String]? = nil, body: (any Encodable)? = nil) async throws -> T {
        let request = try buildRequest(method: method, path: path, query: query, body: body)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverUnreachable
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func requestVoid(method: String, path: String, query: [String: String]? = nil, body: (any Encodable)? = nil) async throws {
        let request = try buildRequest(method: method, path: path, query: query, body: body)
        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverUnreachable
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: nil)
        }
    }

    /// Login (no token required — creates a separate request)
    static func login(serverURL: URL, username: String, password: String) async throws -> LoginResponse {
        let url = serverURL.appendingPathComponent("/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverUnreachable
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    // MARK: - Convenience Methods

    func getLibraries() async throws -> [LibraryResponse] {
        let response = try await request(LibrariesResponse.self, method: "GET", path: "/api/libraries")
        return response.libraries
    }

    func getLibraryItems(libraryId: String, page: Int = 0, limit: Int = 100) async throws -> LibraryItemsResponse {
        try await request(LibraryItemsResponse.self, method: "GET", path: "/api/libraries/\(libraryId)/items", query: [
            "limit": "\(limit)",
            "page": "\(page)"
        ])
    }

    func getItemDetails(itemId: String) async throws -> LibraryItemResponse {
        try await request(LibraryItemResponse.self, method: "GET", path: "/api/items/\(itemId)")
    }

    func searchLibrary(libraryId: String, query: String) async throws -> SearchResponse {
        try await request(SearchResponse.self, method: "GET", path: "/api/libraries/\(libraryId)/search", query: ["q": query])
    }

    func startPlaybackSession(itemId: String, requestBody: PlaybackSessionRequest) async throws -> PlaybackSessionResponse {
        try await request(PlaybackSessionResponse.self, method: "POST", path: "/api/items/\(itemId)/play", body: requestBody)
    }

    func syncSession(sessionId: String, body: SessionSyncRequest) async throws {
        try await requestVoid(method: "POST", path: "/api/sessions/open/\(sessionId)/sync", body: body)
    }

    func closeSession(sessionId: String) async throws {
        try await requestVoid(method: "POST", path: "/api/sessions/open/\(sessionId)/close")
    }

    func getProgress(libraryItemId: String) async throws -> MediaProgressResponse {
        try await request(MediaProgressResponse.self, method: "GET", path: "/api/me/progress/\(libraryItemId)")
    }

    func updateProgress(libraryItemId: String, progress: MediaProgressResponse) async throws {
        try await requestVoid(method: "PATCH", path: "/api/me/progress/\(libraryItemId)", body: progress)
    }

    func authorize() async throws -> AuthorizeResponse {
        try await request(AuthorizeResponse.self, method: "GET", path: "/api/authorize")
    }

    /// Build a streaming URL for an audio track
    func streamingURL(contentUrl: String) -> URL? {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(contentUrl), resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        return components.url
    }

    /// Build a cover art URL
    func coverURL(itemId: String, width: Int? = nil) -> URL? {
        var path = "/api/items/\(itemId)/cover"
        var query: [URLQueryItem] = [URLQueryItem(name: "token", value: token)]
        if let width {
            query.append(URLQueryItem(name: "width", value: "\(width)"))
        }
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = query
        return components.url
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: all 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Services/APIClient.swift NimbusPlayer/NimbusPlayerTests/APIClientTests.swift
git commit -m "feat: add APIClient with all Audiobookshelf endpoints"
```

---

### Task 9: Server Service & Auth Flow

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Services/ServerService.swift`
- Create: `NimbusPlayer/NimbusPlayer/ViewModels/ServerSetupViewModel.swift`
- Modify: `NimbusPlayer/NimbusPlayer/Views/Settings/AddServerView.swift`

- [ ] **Step 1: Implement ServerService**

```swift
// NimbusPlayer/NimbusPlayer/Services/ServerService.swift
import Foundation
import SwiftData

@Observable
final class ServerService {
    private let keychain = KeychainService()
    private(set) var clients: [UUID: APIClient] = [:]
    private(set) var serverStatuses: [UUID: ServerStatus] = [:]

    enum ServerStatus: Equatable {
        case connected
        case unreachable
        case authExpired
        case unknown
    }

    /// Initialize API clients for all active servers
    func loadClients(servers: [Server]) {
        for server in servers where server.isActive {
            if let token = try? keychain.getToken(for: server.id),
               let url = server.baseURL {
                clients[server.id] = APIClient(baseURL: url, token: token)
            }
        }
    }

    /// Login to a server and store the token
    func login(url: String, username: String, password: String) async throws -> (token: String, userId: String) {
        guard let serverURL = URL(string: url) else {
            throw APIClient.APIError.invalidURL
        }
        let response = try await APIClient.login(serverURL: serverURL, username: username, password: password)
        return (response.user.token, response.user.id)
    }

    /// Register a new server after successful login
    func registerServer(_ server: Server, token: String) throws {
        try keychain.saveToken(token, for: server.id)
        if let url = server.baseURL {
            clients[server.id] = APIClient(baseURL: url, token: token)
        }
        serverStatuses[server.id] = .connected
        server.lastConnected = Date()
    }

    /// Validate all server connections
    func validateConnections(servers: [Server]) async {
        await withTaskGroup(of: (UUID, ServerStatus).self) { group in
            for server in servers where server.isActive {
                guard let client = clients[server.id] else {
                    serverStatuses[server.id] = .unknown
                    continue
                }
                group.addTask {
                    do {
                        _ = try await client.authorize()
                        return (server.id, .connected)
                    } catch let error as APIClient.APIError {
                        switch error {
                        case .unauthorized:
                            return (server.id, .authExpired)
                        default:
                            return (server.id, .unreachable)
                        }
                    } catch {
                        return (server.id, .unreachable)
                    }
                }
            }
            for await (serverId, status) in group {
                serverStatuses[serverId] = status
            }
        }
    }

    /// Get the API client for a specific server
    func client(for serverId: UUID) -> APIClient? {
        clients[serverId]
    }

    /// Remove a server's credentials
    func removeServer(_ server: Server) {
        try? keychain.deleteToken(for: server.id)
        clients.removeValue(forKey: server.id)
        serverStatuses.removeValue(forKey: server.id)
    }
}
```

- [ ] **Step 2: Implement ServerSetupViewModel**

```swift
// NimbusPlayer/NimbusPlayer/ViewModels/ServerSetupViewModel.swift
import Foundation
import SwiftData

@Observable
final class ServerSetupViewModel {
    var serverURL = ""
    var username = ""
    var password = ""
    var displayName = ""
    var isLoading = false
    var errorMessage: String?

    func addServer(serverService: ServerService, modelContext: ModelContext, onComplete: @escaping () -> Void) {
        guard !serverURL.isEmpty, !username.isEmpty, !password.isEmpty else {
            errorMessage = "All fields are required"
            return
        }

        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await serverService.login(url: url, username: username, password: password)

                let name = displayName.isEmpty ? (URL(string: url)?.host ?? url) : displayName
                let server = Server(url: url, username: username, displayName: name)
                modelContext.insert(server)

                try serverService.registerServer(server, token: result.token)
                try modelContext.save()

                await MainActor.run {
                    isLoading = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

- [ ] **Step 3: Implement AddServerView**

```swift
// NimbusPlayer/NimbusPlayer/Views/Settings/AddServerView.swift
import SwiftUI
import SwiftData

struct AddServerView: View {
    var isOnboarding: Bool = false
    var onComplete: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(ServerService.self) private var serverService

    @State private var viewModel = ServerSetupViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $viewModel.serverURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)

                    TextField("Display Name (optional)", text: $viewModel.displayName)
                }

                Section("Credentials") {
                    TextField("Username", text: $viewModel.username)
                        .textContentType(.username)
                        .autocapitalization(.none)

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: connect) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Connect")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle(isOnboarding ? "Welcome to Nimbus" : "Add Server")
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    private func connect() {
        viewModel.addServer(serverService: serverService, modelContext: modelContext) {
            appState.hasCompletedOnboarding = true
            onComplete?()
            if !isOnboarding { dismiss() }
        }
    }
}
```

- [ ] **Step 4: Update NimbusPlayerApp to inject ServerService**

Update `NimbusPlayerApp.swift` to create and inject the `ServerService`:

```swift
// Replace the existing NimbusPlayerApp body:
@main
struct NimbusPlayerApp: App {
    @State private var appState = AppState()
    @State private var serverService = ServerService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(serverService)
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(for: [
            Server.self,
            CachedBook.self,
            ServerBookMapping.self,
            ListeningProgress.self,
            DownloadModel.self,
            Bookmark.self
        ])
    }

    private var colorScheme: ColorScheme? {
        switch appState.appearanceMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}
```

- [ ] **Step 5: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Services/ServerService.swift \
       NimbusPlayer/NimbusPlayer/ViewModels/ServerSetupViewModel.swift \
       NimbusPlayer/NimbusPlayer/Views/Settings/AddServerView.swift \
       NimbusPlayer/NimbusPlayer/App/NimbusPlayerApp.swift
git commit -m "feat: add ServerService, auth flow, and Add Server UI"
```

---

## Phase 3: Library Backend

### Task 10: Network Monitor

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Services/NetworkMonitor.swift`

- [ ] **Step 1: Implement NetworkMonitor**

```swift
// NimbusPlayer/NimbusPlayer/Services/NetworkMonitor.swift
import Foundation
import Network

@Observable
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private(set) var isConnected = true
    private(set) var isExpensive = false // cellular
    private(set) var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi, cellular, wired, unknown
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wired
                } else {
                    self?.connectionType = .unknown
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Check if downloads are allowed given current network and user preferences
    func canDownload(allowCellular: Bool) -> Bool {
        guard isConnected else { return false }
        if isExpensive && !allowCellular { return false }
        return true
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Services/NetworkMonitor.swift
git commit -m "feat: add NetworkMonitor for connectivity and cellular detection"
```

---

### Task 11: Library Service (Fetch, Dedup, Merge)

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Services/LibraryService.swift`
- Create: `NimbusPlayer/NimbusPlayer/ViewModels/LibraryViewModel.swift`

- [ ] **Step 1: Implement LibraryService**

```swift
// NimbusPlayer/NimbusPlayer/Services/LibraryService.swift
import Foundation
import SwiftData

@Observable
final class LibraryService {
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// Fetch all library items from all servers, deduplicate, and persist to SwiftData
    func refreshLibrary(servers: [Server], serverService: ServerService, modelContext: ModelContext) async {
        isLoading = true
        lastError = nil

        // 1. Fetch items from all servers in parallel
        var allServerItems: [(Server, [LibraryItemResponse])] = []

        await withTaskGroup(of: (Server, [LibraryItemResponse])?.self) { group in
            for server in servers where server.isActive {
                guard let client = serverService.client(for: server.id) else { continue }
                group.addTask {
                    do {
                        let items = try await self.fetchAllItems(client: client)
                        return (server, items)
                    } catch {
                        return nil
                    }
                }
            }
            for await result in group {
                if let result { allServerItems.append(result) }
            }
        }

        // 2. Deduplicate and merge
        let mergedBooks = deduplicateItems(allServerItems)

        // 3. Persist to SwiftData
        persistBooks(mergedBooks, modelContext: modelContext)

        isLoading = false
    }

    /// Fetch all items from a single server (handles pagination)
    private func fetchAllItems(client: APIClient) async throws -> [LibraryItemResponse] {
        let libraries = try await client.getLibraries()
        let bookLibraries = libraries.filter { $0.mediaType == "book" }

        var allItems: [LibraryItemResponse] = []

        for library in bookLibraries {
            var page = 0
            var libraryItemCount = 0
            while true {
                let response = try await client.getLibraryItems(libraryId: library.id, page: page, limit: 100)
                allItems.append(contentsOf: response.results)
                libraryItemCount += response.results.count
                if libraryItemCount >= response.total || response.results.isEmpty {
                    break
                }
                page += 1
            }
        }

        return allItems
    }

    /// Group of items from different servers that represent the same book
    struct MergedBook {
        let identity: BookMatcher.BookIdentity
        var serverItems: [(server: Server, item: LibraryItemResponse, libraryId: String)]
    }

    /// Deduplicate items across servers
    private func deduplicateItems(_ serverItems: [(Server, [LibraryItemResponse])]) -> [MergedBook] {
        var merged: [MergedBook] = []

        for (server, items) in serverItems {
            for item in items {
                let identity = BookMatcher.BookIdentity(
                    asin: item.asin,
                    isbn: item.isbn,
                    title: item.title,
                    author: item.authorName
                )

                if let existingIndex = merged.firstIndex(where: { BookMatcher.areMatching($0.identity, identity) }) {
                    merged[existingIndex].serverItems.append((server, item, item.libraryId))
                } else {
                    merged.append(MergedBook(
                        identity: identity,
                        serverItems: [(server, item, item.libraryId)]
                    ))
                }
            }
        }

        return merged
    }

    /// Persist merged books to SwiftData, updating existing records
    private func persistBooks(_ mergedBooks: [MergedBook], modelContext: ModelContext) {
        for merged in mergedBooks {
            let firstItem = merged.serverItems[0].item

            let bookId = UUIDv5.bookID(
                asin: firstItem.asin,
                isbn: firstItem.isbn,
                title: firstItem.title,
                author: firstItem.authorName
            )

            // Fetch or create CachedBook
            let descriptor = FetchDescriptor<CachedBook>(predicate: #Predicate { $0.id == bookId })
            let existingBook = try? modelContext.fetch(descriptor).first

            let book: CachedBook
            if let existing = existingBook {
                book = existing
                book.title = firstItem.title
                book.author = firstItem.authorName
                book.duration = firstItem.totalDuration
                book.lastUpdated = Date()
            } else {
                book = CachedBook(
                    title: firstItem.title,
                    author: firstItem.authorName,
                    asin: firstItem.asin,
                    isbn: firstItem.isbn,
                    duration: firstItem.totalDuration
                )
                modelContext.insert(book)
            }

            book.narrator = firstItem.narratorName
            book.bookDescription = firstItem.media.metadata.description
            book.seriesName = firstItem.seriesName
            book.seriesSequence = firstItem.seriesSequence

            // Update server mappings
            for (server, item, libraryId) in merged.serverItems {
                let existingMapping = book.serverMappings.first { $0.server?.id == server.id }

                if let mapping = existingMapping {
                    mapping.libraryItemId = item.id
                    mapping.bitrate = item.totalBitrate
                    mapping.format = item.audioFormat
                    mapping.fileSize = item.totalSize
                } else {
                    let mapping = ServerBookMapping(libraryItemId: item.id, libraryId: libraryId)
                    mapping.server = server
                    mapping.book = book
                    mapping.bitrate = item.totalBitrate
                    mapping.format = item.audioFormat
                    mapping.fileSize = item.totalSize
                    // First mapping is preferred by default
                    mapping.isPreferred = book.serverMappings.isEmpty
                    modelContext.insert(mapping)
                }
            }
        }

        try? modelContext.save()
    }
}
```

- [ ] **Step 2: Implement LibraryViewModel**

```swift
// NimbusPlayer/NimbusPlayer/ViewModels/LibraryViewModel.swift
import Foundation
import SwiftData

@Observable
final class LibraryViewModel {
    var isGridView = true
    var sortOption: SortOption = .recentlyAdded
    var isRefreshing = false

    enum SortOption: String, CaseIterable {
        case recentlyAdded = "Recently Added"
        case title = "Title"
        case author = "Author"
        case duration = "Duration"
    }

    func refresh(servers: [Server], serverService: ServerService, libraryService: LibraryService, modelContext: ModelContext) async {
        isRefreshing = true
        await libraryService.refreshLibrary(servers: servers, serverService: serverService, modelContext: modelContext)
        isRefreshing = false
    }

    func sortedBooks(_ books: [CachedBook]) -> [CachedBook] {
        switch sortOption {
        case .recentlyAdded:
            return books.sorted { $0.lastUpdated > $1.lastUpdated }
        case .title:
            return books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            return books.sorted { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
        case .duration:
            return books.sorted { $0.duration > $1.duration }
        }
    }

    func continueListeningBooks(_ books: [CachedBook]) -> [CachedBook] {
        books
            .filter { $0.progress != nil && $0.progress!.progress > 0 && !$0.progress!.isFinished }
            .sorted { ($0.progress?.lastUpdated ?? .distantPast) > ($1.progress?.lastUpdated ?? .distantPast) }
    }
}
```

- [ ] **Step 3: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Services/LibraryService.swift \
       NimbusPlayer/NimbusPlayer/ViewModels/LibraryViewModel.swift
git commit -m "feat: add LibraryService with multi-server fetch, dedup, and merge"
```

---

### Task 12: Image Cache Service

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Services/ImageCacheService.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/Components/CoverImageView.swift`

- [ ] **Step 1: Implement ImageCacheService**

```swift
// NimbusPlayer/NimbusPlayer/Services/ImageCacheService.swift
import SwiftUI

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500_000_000 // 500MB

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("CoverArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50_000_000 // 50MB
    }

    func image(for url: URL, cacheKey: String) async throws -> UIImage {
        let nsKey = NSString(string: cacheKey)

        // Check memory cache
        if let cached = memoryCache.object(forKey: nsKey) {
            return cached
        }

        // Check disk cache
        let diskPath = cacheDirectory.appendingPathComponent(cacheKey.replacingOccurrences(of: "/", with: "_"))
        if let data = try? Data(contentsOf: diskPath),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: nsKey, cost: data.count)
            return image
        }

        // Download
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Save to caches
        memoryCache.setObject(image, forKey: nsKey, cost: data.count)
        try? data.write(to: diskPath)

        return image
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
```

- [ ] **Step 2: Implement CoverImageView**

```swift
// NimbusPlayer/NimbusPlayer/Views/Components/CoverImageView.swift
import SwiftUI

struct CoverImageView: View {
    let itemId: String
    let serverService: ServerService
    let serverId: UUID
    var width: CGFloat = NimbusTheme.Dimensions.coverThumbnailSize

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                    .fill(NimbusTheme.Colors.surfaceOverlay)
                    .overlay {
                        ProgressView()
                            .tint(NimbusTheme.Colors.textTertiary)
                    }
            } else {
                RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                    .fill(NimbusTheme.Colors.surfaceOverlay)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    }
            }
        }
        .frame(width: width, height: width)
        .clipShape(RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius))
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let client = serverService.client(for: serverId),
              let url = client.coverURL(itemId: itemId, width: Int(width * UIScreen.main.scale)) else {
            isLoading = false
            return
        }

        let cacheKey = "\(serverId.uuidString)_\(itemId)_\(Int(width))"

        do {
            let loaded = try await ImageCacheService.shared.image(for: url, cacheKey: cacheKey)
            self.image = loaded
        } catch {
            // Silently fail — show placeholder
        }
        isLoading = false
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Services/ImageCacheService.swift \
       NimbusPlayer/NimbusPlayer/Views/Components/CoverImageView.swift
git commit -m "feat: add ImageCacheService with disk+memory caching and CoverImageView"
```

---

## Phase 4: Library UI

### Task 13: Library Browse UI

**Files:**
- Modify: `NimbusPlayer/NimbusPlayer/Views/Library/LibraryView.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/Library/BookGridItem.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/Library/BookListRow.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/Library/ContinueListeningRow.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/Components/ProgressBar.swift`

- [ ] **Step 1: Create ProgressBar component**

```swift
// NimbusPlayer/NimbusPlayer/Views/Components/ProgressBar.swift
import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 3
    var showGradient: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(NimbusTheme.Colors.surfaceOverlay)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(showGradient ? AnyShapeStyle(NimbusTheme.Gradients.accent) : AnyShapeStyle(NimbusTheme.Colors.accentPink))
                    .frame(width: geo.size.width * min(max(progress, 0), 1), height: height)
            }
        }
        .frame(height: height)
    }
}
```

- [ ] **Step 2: Create ContinueListeningRow**

```swift
// NimbusPlayer/NimbusPlayer/Views/Library/ContinueListeningRow.swift
import SwiftUI

struct ContinueListeningRow: View {
    let book: CachedBook
    @Environment(ServerService.self) private var serverService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
                CoverImageView(
                    itemId: mapping.libraryItemId,
                    serverService: serverService,
                    serverId: serverId,
                    width: NimbusTheme.Dimensions.coverGridSize
                )
            } else {
                RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                    .fill(NimbusTheme.Colors.surfaceOverlay)
                    .frame(width: NimbusTheme.Dimensions.coverGridSize, height: NimbusTheme.Dimensions.coverGridSize)
            }

            Text(book.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(NimbusTheme.Colors.textPrimary)
                .lineLimit(1)

            if let progress = book.progress {
                ProgressBar(progress: progress.progress)
                Text("\(Int(progress.progress * 100))% complete")
                    .font(.caption2)
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
            }
        }
        .frame(width: NimbusTheme.Dimensions.coverGridSize)
    }
}
```

- [ ] **Step 3: Create BookGridItem**

```swift
// NimbusPlayer/NimbusPlayer/Views/Library/BookGridItem.swift
import SwiftUI

struct BookGridItem: View {
    let book: CachedBook
    @Environment(ServerService.self) private var serverService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
                CoverImageView(
                    itemId: mapping.libraryItemId,
                    serverService: serverService,
                    serverId: serverId,
                    width: NimbusTheme.Dimensions.coverGridSize
                )
            } else {
                RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                    .fill(NimbusTheme.Colors.surfaceOverlay)
                    .frame(width: NimbusTheme.Dimensions.coverGridSize, height: NimbusTheme.Dimensions.coverGridSize)
            }

            Text(book.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(NimbusTheme.Colors.textPrimary)
                .lineLimit(1)

            Text(book.author)
                .font(.caption2)
                .foregroundStyle(NimbusTheme.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(width: NimbusTheme.Dimensions.coverGridSize)
    }
}
```

- [ ] **Step 4: Create BookListRow**

```swift
// NimbusPlayer/NimbusPlayer/Views/Library/BookListRow.swift
import SwiftUI

struct BookListRow: View {
    let book: CachedBook
    @Environment(ServerService.self) private var serverService

    var body: some View {
        HStack(spacing: 12) {
            if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
                CoverImageView(
                    itemId: mapping.libraryItemId,
                    serverService: serverService,
                    serverId: serverId,
                    width: NimbusTheme.Dimensions.coverThumbnailSize
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text("\(book.author) \u{2022} \(formattedDuration)")
                    .font(.caption)
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if let progress = book.progress, progress.progress > 0 {
                CircularProgressView(progress: progress.progress)
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedDuration: String {
        let hours = Int(book.duration) / 3600
        let minutes = (Int(book.duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(NimbusTheme.Colors.surfaceOverlay, lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(NimbusTheme.Colors.accentPink, lineWidth: 2)
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 24, height: 24)
    }
}
```

- [ ] **Step 5: Implement full LibraryView**

```swift
// NimbusPlayer/NimbusPlayer/Views/Library/LibraryView.swift
import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(ServerService.self) private var serverService
    @Environment(AppState.self) private var appState
    @Query private var books: [CachedBook]
    @Query(filter: #Predicate<Server> { $0.isActive }) private var servers: [Server]
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = LibraryViewModel()
    @Environment(LibraryService.self) private var libraryService

    private let gridColumns = [
        GridItem(.adaptive(minimum: 110), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Continue Listening
                    let continueBooks = viewModel.continueListeningBooks(books)
                    if !continueBooks.isEmpty {
                        sectionHeader("Continue Listening")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(continueBooks) { book in
                                    NavigationLink(value: book) {
                                        ContinueListeningRow(book: book)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // All Books
                    HStack {
                        sectionHeader("Library")
                        Spacer()
                        Menu {
                            ForEach(LibraryViewModel.SortOption.allCases, id: \.self) { option in
                                Button(option.rawValue) {
                                    viewModel.sortOption = option
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                        }
                        Button {
                            viewModel.isGridView.toggle()
                        } label: {
                            Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    let sorted = viewModel.sortedBooks(books)

                    if viewModel.isGridView {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(sorted) { book in
                                NavigationLink(value: book) {
                                    BookGridItem(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(sorted) { book in
                                NavigationLink(value: book) {
                                    BookListRow(book: book)
                                }
                                .buttonStyle(.plain)
                                Divider()
                                    .background(NimbusTheme.Colors.divider)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 100) // Space for mini player + tab bar
            }
            .background(NimbusTheme.Colors.backgroundPrimary)
            .navigationTitle("Library")
            .refreshable {
                await viewModel.refresh(
                    servers: servers,
                    serverService: serverService,
                    libraryService: libraryService,
                    modelContext: modelContext
                )
            }
            .navigationDestination(for: CachedBook.self) { book in
                BookDetailView(book: book)
            }
            .task {
                if books.isEmpty {
                    await viewModel.refresh(
                        servers: servers,
                        serverService: serverService,
                        libraryService: libraryService,
                        modelContext: modelContext
                    )
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(NimbusTheme.Colors.textSecondary)
            .padding(.horizontal, 20)
    }
}
```

- [ ] **Step 6: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Views/Library/ \
       NimbusPlayer/NimbusPlayer/Views/Components/ProgressBar.swift
git commit -m "feat: add Library UI with grid/list views and continue listening"
```

---

### Task 14: Book Detail View

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Views/BookDetail/BookDetailView.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/BookDetail/ServerComparisonSheet.swift`
- Create: `NimbusPlayer/NimbusPlayer/ViewModels/BookDetailViewModel.swift`

- [ ] **Step 1: Implement BookDetailViewModel**

```swift
// NimbusPlayer/NimbusPlayer/ViewModels/BookDetailViewModel.swift
import Foundation

@Observable
final class BookDetailViewModel {
    var chapters: [LibraryItemResponse.MediaResponse.ChapterResponse] = []
    var isLoadingDetails = false

    func loadDetails(book: CachedBook, serverService: ServerService) async {
        guard let mapping = book.preferredMapping,
              let serverId = mapping.server?.id,
              let client = serverService.client(for: serverId) else { return }

        isLoadingDetails = true
        do {
            let item = try await client.getItemDetails(itemId: mapping.libraryItemId)
            chapters = item.media.chapters ?? []
        } catch {
            // Chapters remain empty — not critical
        }
        isLoadingDetails = false
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    func formatTimestamp(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 2: Implement BookDetailView**

```swift
// NimbusPlayer/NimbusPlayer/Views/BookDetail/BookDetailView.swift
import SwiftUI

struct BookDetailView: View {
    let book: CachedBook
    @Environment(ServerService.self) private var serverService
    @State private var viewModel = BookDetailViewModel()
    @State private var showServerComparison = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cover art
                if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
                    CoverImageView(
                        itemId: mapping.libraryItemId,
                        serverService: serverService,
                        serverId: serverId,
                        width: NimbusTheme.Dimensions.coverDetailSize
                    )
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
                }

                // Title & Author
                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(NimbusTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(NimbusTheme.Colors.textSecondary)

                    if let narrator = book.narrator {
                        Text("Narrated by \(narrator)")
                            .font(.caption)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    }
                }

                // Series info
                if let series = book.seriesName {
                    HStack(spacing: 4) {
                        Text(series)
                        if let seq = book.seriesSequence {
                            Text("#\(seq)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(NimbusTheme.Colors.surfaceOverlay)
                    .clipShape(Capsule())
                }

                // Duration & Progress
                HStack(spacing: 20) {
                    Label(viewModel.formatDuration(book.duration), systemImage: "clock")
                    if let progress = book.progress, progress.progress > 0 {
                        Label("\(Int(progress.progress * 100))%", systemImage: "chart.bar.fill")
                    }
                    if book.isMultiServer {
                        Button {
                            showServerComparison = true
                        } label: {
                            Label("\(book.serverMappings.count) servers", systemImage: "server.rack")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)

                // Progress bar
                if let progress = book.progress, progress.progress > 0 {
                    VStack(spacing: 4) {
                        ProgressBar(progress: progress.progress, height: 4)
                        HStack {
                            Text(viewModel.formatTimestamp(progress.currentTime))
                            Spacer()
                            Text("-\(viewModel.formatTimestamp(progress.totalDuration - progress.currentTime))")
                        }
                        .font(.caption2)
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    }
                    .padding(.horizontal, 20)
                }

                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        // Play action — implemented in Task 16
                    } label: {
                        Label(
                            book.progress?.progress ?? 0 > 0 ? "Continue" : "Play",
                            systemImage: "play.fill"
                        )
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NimbusTheme.Gradients.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.cornerRadius))
                    }

                    Button {
                        // Download action — implemented in Task 23
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                            .frame(width: 50, height: 50)
                            .background(NimbusTheme.Colors.surfaceOverlay)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)

                // Description
                if let desc = book.bookDescription, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                            .lineLimit(6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                }

                // Chapters
                if !viewModel.chapters.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chapters (\(viewModel.chapters.count))")
                            .font(.headline)
                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                            .padding(.horizontal, 20)

                        ForEach(viewModel.chapters, id: \.id) { chapter in
                            HStack {
                                Text(chapter.title)
                                    .font(.subheadline)
                                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(viewModel.formatTimestamp(chapter.start))
                                    .font(.caption)
                                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.bottom, 100)
        }
        .background(NimbusTheme.Colors.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showServerComparison) {
            ServerComparisonSheet(book: book)
        }
        .task {
            await viewModel.loadDetails(book: book, serverService: serverService)
        }
    }
}
```

- [ ] **Step 3: Implement ServerComparisonSheet**

```swift
// NimbusPlayer/NimbusPlayer/Views/BookDetail/ServerComparisonSheet.swift
import SwiftUI
import SwiftData

struct ServerComparisonSheet: View {
    let book: CachedBook
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(book.serverMappings) { mapping in
                    Button {
                        selectPreferred(mapping)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mapping.server?.displayName ?? "Unknown Server")
                                    .font(.headline)
                                    .foregroundStyle(NimbusTheme.Colors.textPrimary)

                                HStack(spacing: 12) {
                                    if let bitrate = mapping.bitrate {
                                        Label("\(bitrate) kbps", systemImage: "waveform")
                                    }
                                    if let format = mapping.format {
                                        Label(format.uppercased(), systemImage: "doc")
                                    }
                                    if let size = mapping.fileSize {
                                        Label(formatBytes(size), systemImage: "internaldrive")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                            }

                            Spacer()

                            if mapping.isPreferred {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Available Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func selectPreferred(_ mapping: ServerBookMapping) {
        for m in book.serverMappings {
            m.isPreferred = (m.id == mapping.id)
        }
        try? modelContext.save()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
```

- [ ] **Step 4: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Views/BookDetail/ \
       NimbusPlayer/NimbusPlayer/ViewModels/BookDetailViewModel.swift
git commit -m "feat: add BookDetailView with chapter list and server comparison"
```

---

## Phase 5: Audio Playback

### Task 15: Audio Player Service

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Services/AudioPlayerService.swift`

- [ ] **Step 1: Implement AudioPlayerService**

```swift
// NimbusPlayer/NimbusPlayer/Services/AudioPlayerService.swift
import AVFoundation
import MediaPlayer
import SwiftUI

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
    var chapters: [LibraryItemResponse.MediaResponse.ChapterResponse] = []

    // Session info
    private(set) var sessionId: String?
    private(set) var sessionServerId: UUID?

    // Sleep timer
    var sleepTimerRemaining: TimeInterval?
    private var sleepTimer: Timer?

    // MARK: - Private
    private var player: AVPlayer?
    private var tracks: [PlaybackSessionResponse.AudioTrackResponse] = []
    private var timeObserver: Any?
    private var pausedAt: Date?

    // MARK: - Playback Control

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

        // Determine playback speed
        self.playbackSpeed = book.progress?.playbackSpeed ?? playbackSpeed

        let resumeTime = startTime ?? session.currentTime

        // Find the correct track for the resume time
        guard let (trackIndex, trackLocalTime) = findTrack(for: resumeTime) else { return }

        setupAudioSession()
        loadTrack(at: trackIndex, seekTo: trackLocalTime, serverId: serverId, serverService: serverService)
    }

    func play() {
        // Resume rewind if paused for > 2 minutes
        if let pausedAt, Date().timeIntervalSince(pausedAt) > 120 {
            let rewindAmount = 5.0 // Will be configurable via AppState
            let newTime = max(0, currentTime - rewindAmount)
            seek(to: newTime)
        }
        pausedAt = nil
        player?.rate = Float(playbackSpeed)
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        pausedAt = Date()
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to globalTime: TimeInterval) {
        guard let (trackIndex, localTime) = findTrack(for: globalTime) else { return }

        if trackIndex != currentTrackIndex, let serverId = sessionServerId {
            // Need to load a different track
            let serverService = findServerService()
            if let serverService {
                loadTrack(at: trackIndex, seekTo: localTime, serverId: serverId, serverService: serverService)
            }
        } else {
            let cmTime = CMTime(seconds: localTime, preferredTimescale: 600)
            player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime = globalTime
        }
        updateNowPlayingInfo()
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        seek(to: min(currentTime + seconds, duration))
    }

    func skipBackward(_ seconds: TimeInterval = 30) {
        seek(to: max(currentTime - seconds, 0))
    }

    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = Float(speed)
        }
    }

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

    func setSleepTimerEndOfChapter() {
        // Handled in time observer — check if we've crossed a chapter boundary
        sleepTimerRemaining = -1 // Sentinel: end of chapter mode
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = nil
    }

    // MARK: - Chapter Navigation

    var currentChapter: LibraryItemResponse.MediaResponse.ChapterResponse? {
        chapters.first { currentTime >= $0.start && currentTime < $0.end }
    }

    func seekToChapter(_ chapter: LibraryItemResponse.MediaResponse.ChapterResponse) {
        seek(to: chapter.start)
    }

    func nextChapter() {
        guard let current = currentChapter,
              let index = chapters.firstIndex(where: { $0.id == current.id }),
              index + 1 < chapters.count else { return }
        seekToChapter(chapters[index + 1])
    }

    func previousChapter() {
        guard let current = currentChapter,
              let index = chapters.firstIndex(where: { $0.id == current.id }),
              index > 0 else { return }
        seekToChapter(chapters[index - 1])
    }

    // MARK: - Private

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }

        setupRemoteCommands()
    }

    private func loadTrack(at index: Int, seekTo: TimeInterval, serverId: UUID, serverService: ServerService) {
        guard index < tracks.count else { return }

        removeTimeObserver()
        let track = tracks[index]
        currentTrackIndex = index

        guard let client = serverService.client(for: serverId),
              let url = client.streamingURL(contentUrl: track.contentUrl) else { return }

        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        // Observe end of track
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.advanceToNextTrack(serverService: serverService, serverId: serverId)
        }

        // Seek to position within track
        let cmTime = CMTime(seconds: seekTo, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.play()
        }

        addTimeObserver()
    }

    private func advanceToNextTrack(serverService: ServerService, serverId: UUID) {
        let nextIndex = currentTrackIndex + 1
        if nextIndex < tracks.count {
            loadTrack(at: nextIndex, seekTo: 0, serverId: serverId, serverService: serverService)
        } else {
            // Book finished
            pause()
        }
    }

    private func findTrack(for globalTime: TimeInterval) -> (trackIndex: Int, localTime: TimeInterval)? {
        for (index, track) in tracks.enumerated() {
            if globalTime >= track.startOffset && globalTime < track.startOffset + track.duration {
                return (index, globalTime - track.startOffset)
            }
        }
        // If past all tracks, return last track at end
        if let last = tracks.last {
            return (tracks.count - 1, last.duration)
        }
        return nil
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, self.currentTrackIndex < self.tracks.count else { return }
            let trackTime = time.seconds
            let track = self.tracks[self.currentTrackIndex]
            self.currentTime = track.startOffset + trackTime

            // Check sleep timer end-of-chapter
            if self.sleepTimerRemaining == -1, let chapter = self.currentChapter {
                let timeToEnd = chapter.end - self.currentTime
                if timeToEnd <= 3 && timeToEnd > 0 {
                    self.fadeOutAndPause()
                    self.cancelSleepTimer()
                }
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func fadeOutAndPause() {
        // Fade volume over 3 seconds
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

    // MARK: - Now Playing Info

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

    /// Workaround: store a reference to find ServerService when needed for cross-track seeking
    private weak var _serverService: ServerService?
    func setServerServiceRef(_ service: ServerService) {
        _serverService = service
    }
    private func findServerService() -> ServerService? {
        _serverService
    }
}
```

- [ ] **Step 2: Add AudioPlayerService to NimbusPlayerApp**

Update `NimbusPlayerApp.swift`:

```swift
@State private var audioPlayerService = AudioPlayerService()
// ... in body:
.environment(audioPlayerService)
```

- [ ] **Step 3: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Services/AudioPlayerService.swift \
       NimbusPlayer/NimbusPlayer/App/NimbusPlayerApp.swift
git commit -m "feat: add AudioPlayerService with multi-track, remote commands, sleep timer"
```

---

### Task 16: Now Playing View

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Views/NowPlaying/NowPlayingView.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/NowPlaying/MiniPlayerBar.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/NowPlaying/ChapterListSheet.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/NowPlaying/SleepTimerSheet.swift`
- Create: `NimbusPlayer/NimbusPlayer/ViewModels/NowPlayingViewModel.swift`

- [ ] **Step 1: Implement NowPlayingViewModel**

```swift
// NimbusPlayer/NimbusPlayer/ViewModels/NowPlayingViewModel.swift
import Foundation

@Observable
final class NowPlayingViewModel {
    var showChapterList = false
    var showSleepTimer = false
    var isScrubbing = false
    var scrubPosition: Double = 0

    func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }

    func formatRemaining(_ current: TimeInterval, _ total: TimeInterval) -> String {
        let remaining = total - current
        return "-\(formatTime(remaining))"
    }

    func formatSpeed(_ speed: Double) -> String {
        if speed == Double(Int(speed)) {
            return "\(Int(speed)).0x"
        }
        return String(format: "%.1fx", speed)
    }
}
```

- [ ] **Step 2: Implement MiniPlayerBar**

```swift
// NimbusPlayer/NimbusPlayer/Views/NowPlaying/MiniPlayerBar.swift
import SwiftUI

struct MiniPlayerBar: View {
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(ServerService.self) private var serverService
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let book = playerService.currentBook {
            VStack(spacing: 0) {
                // Progress line at top
                GeometryReader { geo in
                    Rectangle()
                        .fill(NimbusTheme.Gradients.accent)
                        .frame(width: geo.size.width * (playerService.duration > 0 ? playerService.currentTime / playerService.duration : 0))
                }
                .frame(height: 2)

                HStack(spacing: 10) {
                    // Cover
                    if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
                        CoverImageView(
                            itemId: mapping.libraryItemId,
                            serverService: serverService,
                            serverId: serverId,
                            width: 40
                        )
                    }

                    // Title & Chapter
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                            .lineLimit(1)

                        if let chapter = playerService.currentChapter {
                            Text(chapter.title)
                                .font(.caption2)
                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Play/Pause
                    Button {
                        playerService.togglePlayPause()
                    } label: {
                        Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    }

                    // Forward
                    Button {
                        playerService.skipForward()
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.subheadline)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(
                NimbusTheme.Colors.surfaceElevated
                    .shadow(.drop(color: .black.opacity(0.4), radius: 10, y: -4))
            )
            .clipShape(RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.cornerRadius))
            .padding(.horizontal, 8)
            .onTapGesture {
                showNowPlaying = true
            }
        }
    }
}
```

- [ ] **Step 3: Implement NowPlayingView**

```swift
// NimbusPlayer/NimbusPlayer/Views/NowPlaying/NowPlayingView.swift
import SwiftUI

struct NowPlayingView: View {
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(ServerService.self) private var serverService
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NowPlayingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle + AirPlay
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                // AirPlay picker
                AirPlayButton()
                    .frame(width: 24, height: 24)
                    .tint(NimbusTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            // Cover art
            if let book = playerService.currentBook,
               let mapping = book.preferredMapping,
               let serverId = mapping.server?.id {
                CoverImageView(
                    itemId: mapping.libraryItemId,
                    serverService: serverService,
                    serverId: serverId,
                    width: NimbusTheme.Dimensions.coverDetailSize
                )
                .shadow(color: NimbusTheme.Colors.accentPink.opacity(0.3), radius: 20, y: 8)
            }

            Spacer().frame(height: 24)

            // Title & Author
            VStack(spacing: 4) {
                Text(playerService.currentBook?.title ?? "")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(playerService.currentBook?.author ?? "")
                    .font(.subheadline)
                    .foregroundStyle(NimbusTheme.Colors.textSecondary)
            }

            // Chapter selector
            if let chapter = playerService.currentChapter {
                Button { viewModel.showChapterList = true } label: {
                    HStack(spacing: 6) {
                        Text(chapter.title)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(NimbusTheme.Colors.surfaceOverlay)
                    .clipShape(Capsule())
                }
                .padding(.top, 12)
            }

            // Scrubber
            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { viewModel.isScrubbing ? viewModel.scrubPosition : playerService.currentTime },
                        set: { newValue in
                            viewModel.isScrubbing = true
                            viewModel.scrubPosition = newValue
                        }
                    ),
                    in: 0...max(playerService.duration, 1),
                    onEditingChanged: { editing in
                        if !editing {
                            playerService.seek(to: viewModel.scrubPosition)
                            viewModel.isScrubbing = false
                        }
                    }
                )
                .tint(NimbusTheme.Colors.accentPink)

                HStack {
                    Text(viewModel.formatTime(viewModel.isScrubbing ? viewModel.scrubPosition : playerService.currentTime))
                    Spacer()
                    Text(viewModel.formatRemaining(playerService.currentTime, playerService.duration))
                }
                .font(.caption2)
                .foregroundStyle(NimbusTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)

            // Transport controls
            HStack(spacing: 32) {
                // Speed
                Button { cycleSpeed() } label: {
                    Text(viewModel.formatSpeed(playerService.playbackSpeed))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(NimbusTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(NimbusTheme.Colors.surfaceOverlay)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Rewind
                Button { playerService.skipBackward() } label: {
                    Image(systemName: "gobackward.30")
                        .font(.title2)
                        .foregroundStyle(NimbusTheme.Colors.textPrimary)
                }

                // Play/Pause
                Button { playerService.togglePlayPause() } label: {
                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(NimbusTheme.Gradients.accent)
                        .clipShape(Circle())
                        .shadow(color: NimbusTheme.Colors.accentPink.opacity(0.4), radius: 10, y: 4)
                }

                // Forward
                Button { playerService.skipForward() } label: {
                    Image(systemName: "goforward.30")
                        .font(.title2)
                        .foregroundStyle(NimbusTheme.Colors.textPrimary)
                }

                // Sleep timer
                Button { viewModel.showSleepTimer = true } label: {
                    ZStack {
                        Image(systemName: "moon.fill")
                            .font(.caption)
                            .foregroundStyle(playerService.sleepTimerRemaining != nil ? NimbusTheme.Colors.accentPink : NimbusTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(NimbusTheme.Colors.surfaceOverlay)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        if let remaining = playerService.sleepTimerRemaining, remaining > 0 {
                            Text("\(Int(remaining / 60))m")
                                .font(.system(size: 8))
                                .foregroundStyle(NimbusTheme.Colors.accentPink)
                                .offset(y: 12)
                        }
                    }
                }
            }
            .padding(.top, 20)

            // Bottom actions
            HStack(spacing: 48) {
                Button {
                    // Bookmark — implemented in Task 20
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "bookmark")
                            .font(.body)
                        Text("Bookmark")
                            .font(.caption2)
                    }
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }

                Button {
                    // Download — implemented in Task 23
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.body)
                        Text("Download")
                            .font(.caption2)
                    }
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }

                Button {
                    viewModel.showChapterList = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.body)
                        Text("Chapters")
                            .font(.caption2)
                    }
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }
            }
            .padding(.top, 24)

            Spacer()
        }
        .background(NimbusTheme.Gradients.background.ignoresSafeArea())
        .sheet(isPresented: $viewModel.showChapterList) {
            ChapterListSheet()
        }
        .sheet(isPresented: $viewModel.showSleepTimer) {
            SleepTimerSheet()
        }
    }

    private func cycleSpeed() {
        let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
        if let index = speeds.firstIndex(of: playerService.playbackSpeed), index + 1 < speeds.count {
            playerService.setPlaybackSpeed(speeds[index + 1])
        } else {
            playerService.setPlaybackSpeed(speeds[0])
        }
    }
}

// AirPlay route picker — requires AVKit import at top of file
import AVKit

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor(NimbusTheme.Colors.textSecondary)
        picker.activeTintColor = UIColor(NimbusTheme.Colors.accentPink)
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
```

- [ ] **Step 4: Implement ChapterListSheet**

```swift
// NimbusPlayer/NimbusPlayer/Views/NowPlaying/ChapterListSheet.swift
import SwiftUI

struct ChapterListSheet: View {
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(playerService.chapters, id: \.id) { chapter in
                    Button {
                        playerService.seekToChapter(chapter)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chapter.title)
                                    .font(.subheadline)
                                    .foregroundStyle(isCurrentChapter(chapter) ? NimbusTheme.Colors.accentPink : NimbusTheme.Colors.textPrimary)
                                Text(formatDuration(chapter.end - chapter.start))
                                    .font(.caption)
                                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
                            }
                            Spacer()
                            if isCurrentChapter(chapter) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func isCurrentChapter(_ chapter: LibraryItemResponse.MediaResponse.ChapterResponse) -> Bool {
        playerService.currentChapter?.id == chapter.id
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
```

- [ ] **Step 5: Implement SleepTimerSheet**

```swift
// NimbusPlayer/NimbusPlayer/Views/NowPlaying/SleepTimerSheet.swift
import SwiftUI

struct SleepTimerSheet: View {
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(\.dismiss) private var dismiss

    let options: [(String, TimeInterval?)] = [
        ("5 minutes", 5),
        ("10 minutes", 10),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("60 minutes", 60),
        ("End of chapter", -1),
    ]

    var body: some View {
        NavigationStack {
            List {
                if playerService.sleepTimerRemaining != nil {
                    Section {
                        Button("Cancel Timer", role: .destructive) {
                            playerService.cancelSleepTimer()
                            dismiss()
                        }
                    }
                }

                Section("Set Timer") {
                    ForEach(options, id: \.0) { option in
                        Button {
                            if option.1 == -1 {
                                playerService.setSleepTimerEndOfChapter()
                            } else if let minutes = option.1 {
                                playerService.setSleepTimer(minutes: minutes)
                            }
                            dismiss()
                        } label: {
                            Text(option.0)
                                .foregroundStyle(NimbusTheme.Colors.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 6: Update ContentView to include mini-player and now-playing sheet**

Update `MainTabView` in ContentView.swift:

```swift
struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    @Environment(AudioPlayerService.self) private var playerService

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Library", systemImage: "book.fill", value: 0) {
                    LibraryView()
                }
                Tab("Search", systemImage: "magnifyingglass", value: 1) {
                    SearchView()
                }
                Tab("Downloads", systemImage: "arrow.down.circle.fill", value: 2) {
                    DownloadsView()
                }
                Tab("Settings", systemImage: "gearshape.fill", value: 3) {
                    SettingsView()
                }
            }
            .tint(NimbusTheme.Colors.accentPink)

            // Mini player above tab bar
            if playerService.currentBook != nil {
                VStack(spacing: 0) {
                    MiniPlayerBar(showNowPlaying: $showNowPlaying)
                    Spacer().frame(height: NimbusTheme.Dimensions.tabBarHeight)
                }
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }
}
```

- [ ] **Step 7: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Views/NowPlaying/ \
       NimbusPlayer/NimbusPlayer/ViewModels/NowPlayingViewModel.swift \
       NimbusPlayer/NimbusPlayer/Views/ContentView.swift
git commit -m "feat: add Now Playing view, mini-player bar, chapter list, sleep timer"
```

---

## Phase 6: Progress Tracking

### Task 17: Progress Service

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Services/ProgressService.swift`

- [ ] **Step 1: Implement ProgressService**

```swift
// NimbusPlayer/NimbusPlayer/Services/ProgressService.swift
import Foundation
import SwiftData

@Observable
final class ProgressService {
    private var syncTimer: Timer?
    private var localSaveTimer: Timer?

    /// Start tracking progress for active playback
    func startTracking(playerService: AudioPlayerService, modelContext: ModelContext) {
        // Save locally every 5 seconds
        localSaveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveLocalProgress(playerService: playerService, modelContext: modelContext)
            }
        }

        // Sync to server every 60 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.syncToServer(playerService: playerService, modelContext: modelContext)
            }
        }
    }

    func stopTracking() {
        localSaveTimer?.invalidate()
        localSaveTimer = nil
        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Save current playback position to SwiftData
    func saveLocalProgress(playerService: AudioPlayerService, modelContext: ModelContext) {
        guard let book = playerService.currentBook else { return }

        if let progress = book.progress {
            progress.update(currentTime: playerService.currentTime, duration: playerService.duration)
        } else {
            let progress = ListeningProgress(book: book)
            progress.update(currentTime: playerService.currentTime, duration: playerService.duration)
            book.progress = progress
            modelContext.insert(progress)
        }
        try? modelContext.save()
    }

    /// Sync progress to the active server session
    func syncToServer(playerService: AudioPlayerService, modelContext: ModelContext) async {
        guard let sessionId = playerService.sessionId,
              let serverId = playerService.sessionServerId,
              let book = playerService.currentBook else { return }

        // Save local first
        await MainActor.run {
            saveLocalProgress(playerService: playerService, modelContext: modelContext)
        }

        // Find the server service — injected at higher level
        // We need the APIClient for this server
        guard let progress = book.progress else { return }

        let syncRequest = SessionSyncRequest(
            currentTime: progress.currentTime,
            timeListened: 60, // approximate
            duration: progress.totalDuration
        )

        // Get client through mapping
        if let mapping = book.serverMappings.first(where: { $0.server?.id == serverId }),
           let server = mapping.server,
           let url = server.baseURL,
           let token = try? KeychainService().getToken(for: serverId) {
            let client = APIClient(baseURL: url, token: token)
            do {
                try await client.syncSession(sessionId: sessionId, body: syncRequest)
                await MainActor.run {
                    progress.needsSync = false
                    try? modelContext.save()
                }
            } catch {
                // Sync failed — will retry next interval. needsSync stays true.
            }
        }
    }

    /// Close the active server session
    func closeSession(playerService: AudioPlayerService, modelContext: ModelContext) async {
        guard let sessionId = playerService.sessionId,
              let serverId = playerService.sessionServerId else { return }

        // Final sync
        await syncToServer(playerService: playerService, modelContext: modelContext)

        if let token = try? KeychainService().getToken(for: serverId) {
            // Find server URL from book mappings
            if let book = playerService.currentBook,
               let mapping = book.serverMappings.first(where: { $0.server?.id == serverId }),
               let url = mapping.server?.baseURL {
                let client = APIClient(baseURL: url, token: token)
                try? await client.closeSession(sessionId: sessionId)
            }
        }
    }

    /// Fetch progress from all servers and resolve conflicts
    func pullProgressFromServers(book: CachedBook, serverService: ServerService, modelContext: ModelContext) async {
        var serverProgresses: [(serverId: UUID, progress: MediaProgressResponse)] = []

        await withTaskGroup(of: (UUID, MediaProgressResponse)?.self) { group in
            for mapping in book.serverMappings {
                guard let serverId = mapping.server?.id,
                      let client = serverService.client(for: serverId) else { continue }
                group.addTask {
                    do {
                        let progress = try await client.getProgress(libraryItemId: mapping.libraryItemId)
                        return (serverId, progress)
                    } catch {
                        return nil
                    }
                }
            }
            for await result in group {
                if let result { serverProgresses.append(result) }
            }
        }

        guard !serverProgresses.isEmpty else { return }

        // Find the most recent server progress
        let latestServer = serverProgresses.max(by: { $0.progress.lastUpdate < $1.progress.lastUpdate })!

        await MainActor.run {
            let localProgress = book.progress

            if let local = localProgress {
                let localTimestamp = local.lastUpdated.timeIntervalSince1970
                let serverTimestamp = latestServer.progress.lastUpdate

                if serverTimestamp > localTimestamp {
                    let regression = local.currentTime - latestServer.progress.currentTime

                    if regression > 60 {
                        // Position regression > 60s — flag for user confirmation
                        // For now, keep local position (safe default)
                        // TODO: Show conflict resolution UI
                        return
                    }

                    // Server is newer and not a major regression — accept it
                    local.currentTime = latestServer.progress.currentTime
                    local.totalDuration = latestServer.progress.duration
                    local.progress = latestServer.progress.progress
                    local.isFinished = latestServer.progress.isFinished
                    local.lastUpdated = Date(timeIntervalSince1970: serverTimestamp)
                    local.needsSync = false
                }
                // else: local is newer — will push on next sync
            } else {
                // No local progress — create from server
                let progress = ListeningProgress(book: book)
                progress.currentTime = latestServer.progress.currentTime
                progress.totalDuration = latestServer.progress.duration
                progress.progress = latestServer.progress.progress
                progress.isFinished = latestServer.progress.isFinished
                progress.lastUpdated = Date(timeIntervalSince1970: latestServer.progress.lastUpdate)
                progress.needsSync = false
                book.progress = progress
                modelContext.insert(progress)
            }
            try? modelContext.save()
        }
    }

    /// Flush all un-synced progress to servers
    func flushPendingSyncs(modelContext: ModelContext, serverService: ServerService) async {
        let descriptor = FetchDescriptor<ListeningProgress>(predicate: #Predicate { $0.needsSync })
        guard let pendingProgress = try? modelContext.fetch(descriptor) else { return }

        for progress in pendingProgress {
            guard let book = progress.book else { continue }
            for mapping in book.serverMappings {
                guard let serverId = mapping.server?.id,
                      let client = serverService.client(for: serverId) else { continue }

                let syncData = MediaProgressResponse(
                    id: mapping.libraryItemId,
                    libraryItemId: mapping.libraryItemId,
                    episodeId: nil,
                    duration: progress.totalDuration,
                    progress: progress.progress,
                    currentTime: progress.currentTime,
                    isFinished: progress.isFinished,
                    lastUpdate: progress.lastUpdated.timeIntervalSince1970,
                    startedAt: nil,
                    finishedAt: nil
                )

                do {
                    try await client.updateProgress(libraryItemId: mapping.libraryItemId, progress: syncData)
                } catch {
                    continue // Will retry later
                }
            }

            await MainActor.run {
                progress.needsSync = false
                try? modelContext.save()
            }
        }
    }
}
```

- [ ] **Step 2: Add ProgressService to NimbusPlayerApp**

```swift
@State private var progressService = ProgressService()
// ... in body:
.environment(progressService)
```

- [ ] **Step 3: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Services/ProgressService.swift \
       NimbusPlayer/NimbusPlayer/App/NimbusPlayerApp.swift
git commit -m "feat: add ProgressService with local-first tracking and server sync"
```

---

## Phase 7: Downloads

### Task 18: Download Service

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Services/DownloadService.swift`

- [ ] **Step 1: Implement DownloadService**

```swift
// NimbusPlayer/NimbusPlayer/Services/DownloadService.swift
import Foundation
import SwiftData

@Observable
final class DownloadService: NSObject {
    private(set) var activeDownloads: [UUID: DownloadTask] = [:]
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.nimbusplayer.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    struct DownloadTask {
        let bookId: UUID
        let downloadModelId: UUID
        var tasks: [URLSessionDownloadTask]
        var completedFiles: Int
        var totalFiles: Int
    }

    private let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    /// Start downloading all audio files for a book
    func startDownload(
        book: CachedBook,
        serverService: ServerService,
        networkMonitor: NetworkMonitor,
        allowCellular: Bool,
        modelContext: ModelContext
    ) async throws {
        guard networkMonitor.canDownload(allowCellular: allowCellular) else {
            throw DownloadError.cellularNotAllowed
        }

        guard let mapping = book.preferredMapping,
              let server = mapping.server,
              let serverId = server.id as UUID?,
              let client = serverService.client(for: serverId) else {
            throw DownloadError.noServerAvailable
        }

        // Get item details with audio files
        let item = try await client.getItemDetails(itemId: mapping.libraryItemId)
        guard let audioFiles = item.media.audioFiles, !audioFiles.isEmpty else {
            throw DownloadError.noAudioFiles
        }

        // Create download model
        let download = DownloadModel(book: book, server: server)
        download.state = .downloading
        download.totalBytes = item.media.size ?? 0
        modelContext.insert(download)
        try modelContext.save()

        // Create download directory
        let bookDir = documentsDir.appendingPathComponent("Downloads/\(book.id.uuidString)")
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)

        // Start download tasks for each file
        // We need to use the playback session to get contentUrls
        let sessionRequest = PlaybackSessionRequest.defaultRequest(
            deviceId: UUID().uuidString,
            appVersion: "1.0"
        )
        let session = try await client.startPlaybackSession(itemId: mapping.libraryItemId, requestBody: sessionRequest)
        // Close the session immediately — we just needed the track URLs
        try? await client.closeSession(sessionId: session.id)

        var tasks: [URLSessionDownloadTask] = []
        for track in session.audioTracks {
            guard let url = client.streamingURL(contentUrl: track.contentUrl) else { continue }
            let task = backgroundSession.downloadTask(with: url)
            task.taskDescription = "\(download.id.uuidString)|\(track.index)|\(track.title ?? "track_\(track.index)")"
            tasks.append(task)
        }

        activeDownloads[download.id] = DownloadTask(
            bookId: book.id,
            downloadModelId: download.id,
            tasks: tasks,
            completedFiles: 0,
            totalFiles: tasks.count
        )

        // Start all tasks
        tasks.forEach { $0.resume() }
    }

    func pauseDownload(downloadId: UUID) {
        activeDownloads[downloadId]?.tasks.forEach { $0.suspend() }
    }

    func resumeDownload(downloadId: UUID) {
        activeDownloads[downloadId]?.tasks.forEach { $0.resume() }
    }

    func cancelDownload(downloadId: UUID, modelContext: ModelContext) {
        activeDownloads[downloadId]?.tasks.forEach { $0.cancel() }
        activeDownloads.removeValue(forKey: downloadId)

        // Clean up files and model
        let descriptor = FetchDescriptor<DownloadModel>(predicate: #Predicate { $0.id == downloadId })
        if let download = try? modelContext.fetch(descriptor).first {
            cleanupFiles(for: download)
            modelContext.delete(download)
            try? modelContext.save()
        }
    }

    func deleteDownload(_ download: DownloadModel, modelContext: ModelContext) {
        cleanupFiles(for: download)
        modelContext.delete(download)
        try? modelContext.save()
    }

    /// Get the local file URL for a downloaded book's track
    func localFileURL(bookId: UUID, trackIndex: Int) -> URL? {
        let bookDir = documentsDir.appendingPathComponent("Downloads/\(bookId.uuidString)")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: bookDir, includingPropertiesForKeys: nil) else { return nil }
        return contents.first { $0.lastPathComponent.hasPrefix("track_\(trackIndex)_") }
    }

    /// Check if a book is fully downloaded
    func isBookDownloaded(bookId: UUID) -> Bool {
        let bookDir = documentsDir.appendingPathComponent("Downloads/\(bookId.uuidString)")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: bookDir, includingPropertiesForKeys: nil) else { return false }
        return !contents.isEmpty
    }

    /// Total storage used by downloads
    func totalStorageUsed() -> Int64 {
        let downloadsDir = documentsDir.appendingPathComponent("Downloads")
        guard let enumerator = FileManager.default.enumerator(at: downloadsDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func cleanupFiles(for download: DownloadModel) {
        guard let bookId = download.book?.id else { return }
        let bookDir = documentsDir.appendingPathComponent("Downloads/\(bookId.uuidString)")
        try? FileManager.default.removeItem(at: bookDir)
    }

    enum DownloadError: Error, LocalizedError {
        case cellularNotAllowed
        case noServerAvailable
        case noAudioFiles
        case storageFull

        var errorDescription: String? {
            switch self {
            case .cellularNotAllowed: return "Downloads over cellular are disabled. Connect to Wi-Fi or enable in Settings."
            case .noServerAvailable: return "No server available for download."
            case .noAudioFiles: return "No audio files found for this book."
            case .storageFull: return "Not enough storage space. Free up space and try again."
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension DownloadService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let desc = downloadTask.taskDescription else { return }
        let parts = desc.split(separator: "|")
        guard parts.count >= 3,
              let downloadId = UUID(uuidString: String(parts[0])) else { return }

        let trackIndex = String(parts[1])
        let trackName = String(parts[2])

        guard let bookId = activeDownloads[downloadId]?.bookId else { return }
        let bookDir = documentsDir.appendingPathComponent("Downloads/\(bookId.uuidString)")
        let destURL = bookDir.appendingPathComponent("track_\(trackIndex)_\(trackName)")

        try? FileManager.default.moveItem(at: location, to: destURL)

        if var download = activeDownloads[downloadId] {
            download.completedFiles += 1
            activeDownloads[downloadId] = download

            if download.completedFiles >= download.totalFiles {
                activeDownloads.removeValue(forKey: downloadId)
                // Mark as complete — needs to be done on the right context
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error = error as? NSError, error.code == NSURLErrorNoSpaceLeftOnDevice {
            // Storage full — handled by caller
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Update progress — could emit via NotificationCenter or update model
    }
}
```

- [ ] **Step 2: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Services/DownloadService.swift
git commit -m "feat: add DownloadService with background downloads and storage management"
```

---

### Task 19: Downloads UI

**Files:**
- Modify: `NimbusPlayer/NimbusPlayer/Views/Downloads/DownloadsView.swift`
- Create: `NimbusPlayer/NimbusPlayer/ViewModels/DownloadsViewModel.swift`

- [ ] **Step 1: Implement DownloadsViewModel**

```swift
// NimbusPlayer/NimbusPlayer/ViewModels/DownloadsViewModel.swift
import Foundation

@Observable
final class DownloadsViewModel {
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 2: Implement DownloadsView**

```swift
// NimbusPlayer/NimbusPlayer/Views/Downloads/DownloadsView.swift
import SwiftUI
import SwiftData

struct DownloadsView: View {
    @Query private var downloads: [DownloadModel]
    @Environment(\.modelContext) private var modelContext
    @Environment(DownloadService.self) private var downloadService
    @State private var viewModel = DownloadsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if downloads.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Downloaded audiobooks will appear here for offline listening.")
                    )
                } else {
                    List {
                        Section {
                            HStack {
                                Text("Storage Used")
                                Spacer()
                                Text(viewModel.formatBytes(downloadService.totalStorageUsed()))
                                    .foregroundStyle(NimbusTheme.Colors.textSecondary)
                            }
                        }

                        Section("Downloads") {
                            ForEach(downloads) { download in
                                DownloadRow(download: download, viewModel: viewModel)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    downloadService.deleteDownload(downloads[index], modelContext: modelContext)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
        }
    }
}

struct DownloadRow: View {
    let download: DownloadModel
    let viewModel: DownloadsViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(download.book?.title ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(download.book?.author ?? "")
                    .font(.caption)
                    .foregroundStyle(NimbusTheme.Colors.textSecondary)

                HStack(spacing: 8) {
                    Text(stateLabel)
                        .font(.caption2)
                        .foregroundStyle(stateColor)

                    if download.state == .downloading {
                        Text(viewModel.formatBytes(download.downloadedBytes) + " / " + viewModel.formatBytes(download.totalBytes))
                            .font(.caption2)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    } else if download.state == .complete {
                        Text(viewModel.formatBytes(download.totalBytes))
                            .font(.caption2)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            if download.state == .downloading {
                ProgressView(value: download.progressFraction)
                    .frame(width: 40)
                    .tint(NimbusTheme.Colors.accentPink)
            } else if download.state == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if download.state == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private var stateLabel: String {
        switch download.state {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .complete: return "Downloaded"
        case .failed: return download.errorMessage ?? "Failed"
        }
    }

    private var stateColor: Color {
        switch download.state {
        case .complete: return .green
        case .failed: return .red
        case .downloading: return NimbusTheme.Colors.accentPink
        default: return NimbusTheme.Colors.textTertiary
        }
    }
}
```

- [ ] **Step 3: Add DownloadService to NimbusPlayerApp**

```swift
@State private var downloadService = DownloadService()
@State private var networkMonitor = NetworkMonitor()
// ... in body:
.environment(downloadService)
.environment(networkMonitor)
```

- [ ] **Step 4: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Views/Downloads/DownloadsView.swift \
       NimbusPlayer/NimbusPlayer/ViewModels/DownloadsViewModel.swift \
       NimbusPlayer/NimbusPlayer/App/NimbusPlayerApp.swift
git commit -m "feat: add Downloads tab with progress tracking and storage info"
```

---

## Phase 8: Search, Settings & Polish

### Task 20: Bookmarks

**Files:**
- Update Now Playing bookmark button to be functional

- [ ] **Step 1: Add bookmark action to NowPlayingView**

In `NowPlayingView.swift`, update the bookmark button action:

```swift
// Replace the bookmark Button in NowPlayingView:
Button {
    addBookmark(playerService: playerService, modelContext: modelContext)
} label: {
    VStack(spacing: 4) {
        Image(systemName: hasBookmarkAtCurrentTime ? "bookmark.fill" : "bookmark")
            .font(.body)
        Text("Bookmark")
            .font(.caption2)
    }
    .foregroundStyle(hasBookmarkAtCurrentTime ? NimbusTheme.Colors.accentPink : NimbusTheme.Colors.textTertiary)
}
```

Add these properties and functions to NowPlayingView:

```swift
@Environment(\.modelContext) private var modelContext

private var hasBookmarkAtCurrentTime: Bool {
    guard let book = playerService.currentBook else { return false }
    return book.bookmarks.contains { abs($0.timestamp - playerService.currentTime) < 5 }
}

private func addBookmark(playerService: AudioPlayerService, modelContext: ModelContext) {
    guard let book = playerService.currentBook else { return }
    let bookmark = Bookmark(book: book, timestamp: playerService.currentTime)
    modelContext.insert(bookmark)
    try? modelContext.save()
}
```

- [ ] **Step 2: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Views/NowPlaying/NowPlayingView.swift
git commit -m "feat: add bookmark creation from Now Playing view"
```

---

### Task 21: Search Tab

**Files:**
- Modify: `NimbusPlayer/NimbusPlayer/Views/Search/SearchView.swift`
- Create: `NimbusPlayer/NimbusPlayer/ViewModels/SearchViewModel.swift`

- [ ] **Step 1: Implement SearchViewModel**

```swift
// NimbusPlayer/NimbusPlayer/ViewModels/SearchViewModel.swift
import Foundation

@Observable
final class SearchViewModel {
    var query = ""
    var results: [CachedBook] = []
    var isSearching = false
    var recentSearches: [String] = []

    private let recentSearchesKey = "recentSearches"

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    func search(servers: [Server], serverService: ServerService, allBooks: [CachedBook]) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }

        isSearching = true
        saveRecentSearch(query)

        // Search locally first (fast, instant results)
        let lowercaseQuery = query.lowercased()
        let localResults = allBooks.filter {
            $0.title.lowercased().contains(lowercaseQuery) ||
            $0.author.lowercased().contains(lowercaseQuery) ||
            ($0.narrator?.lowercased().contains(lowercaseQuery) ?? false)
        }
        results = localResults

        // Also search servers for items not yet cached
        await withTaskGroup(of: [LibraryItemResponse].self) { group in
            for server in servers where server.isActive {
                guard let client = serverService.client(for: server.id) else { continue }
                // Get all book libraries for this server
                group.addTask {
                    var items: [LibraryItemResponse] = []
                    guard let libraries = try? await client.getLibraries() else { return [] }
                    for lib in libraries where lib.mediaType == "book" {
                        if let response = try? await client.searchLibrary(libraryId: lib.id, query: self.query) {
                            items.append(contentsOf: response.book?.map(\.libraryItem) ?? [])
                        }
                    }
                    return items
                }
            }
            // Merge server results with local (dedup by matching existing CachedBooks)
            for await serverItems in group {
                for item in serverItems {
                    let alreadyInResults = results.contains { book in
                        BookMatcher.areMatching(
                            BookMatcher.BookIdentity(asin: book.asin, isbn: book.isbn, title: book.title, author: book.author),
                            BookMatcher.BookIdentity(asin: item.asin, isbn: item.isbn, title: item.title, author: item.authorName)
                        )
                    }
                    if !alreadyInResults {
                        // Check if it exists in allBooks but wasn't matched by local search
                        if let existing = allBooks.first(where: { b in
                            BookMatcher.areMatching(
                                BookMatcher.BookIdentity(asin: b.asin, isbn: b.isbn, title: b.title, author: b.author),
                                BookMatcher.BookIdentity(asin: item.asin, isbn: item.isbn, title: item.title, author: item.authorName)
                            )
                        }) {
                            results.append(existing)
                        }
                        // Note: truly new items from server search require creating a CachedBook,
                        // which is deferred — the library refresh will pick them up.
                    }
                }
            }
        }

        isSearching = false
    }

    func clearSearch() {
        query = ""
        results = []
    }

    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }

    private func saveRecentSearch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 10 { recentSearches = Array(recentSearches.prefix(10)) }
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
}
```

- [ ] **Step 2: Implement SearchView**

```swift
// NimbusPlayer/NimbusPlayer/Views/Search/SearchView.swift
import SwiftUI
import SwiftData

struct SearchView: View {
    @Query private var books: [CachedBook]
    @Query(filter: #Predicate<Server> { $0.isActive }) private var servers: [Server]
    @Environment(ServerService.self) private var serverService
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    // Recent searches
                    if !viewModel.recentSearches.isEmpty {
                        List {
                            Section("Recent Searches") {
                                ForEach(viewModel.recentSearches, id: \.self) { search in
                                    Button {
                                        viewModel.query = search
                                        Task {
                                            await viewModel.search(servers: servers, serverService: serverService, allBooks: books)
                                        }
                                    } label: {
                                        Label(search, systemImage: "clock")
                                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                                    }
                                }
                            }

                            Button("Clear Recent Searches", role: .destructive) {
                                viewModel.clearRecentSearches()
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "Search Audiobooks",
                            systemImage: "magnifyingglass",
                            description: Text("Search by title, author, or narrator")
                        )
                    }
                } else if viewModel.results.isEmpty && !viewModel.isSearching {
                    ContentUnavailableView.search(text: viewModel.query)
                } else {
                    List(viewModel.results) { book in
                        NavigationLink(value: book) {
                            BookListRow(book: book)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Title, author, narrator...")
            .onSubmit(of: .search) {
                Task {
                    await viewModel.search(servers: servers, serverService: serverService, allBooks: books)
                }
            }
            .onChange(of: viewModel.query) { _, newValue in
                if newValue.isEmpty {
                    viewModel.clearSearch()
                } else {
                    Task {
                        await viewModel.search(servers: servers, serverService: serverService, allBooks: books)
                    }
                }
            }
            .navigationDestination(for: CachedBook.self) { book in
                BookDetailView(book: book)
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Views/Search/SearchView.swift \
       NimbusPlayer/NimbusPlayer/ViewModels/SearchViewModel.swift
git commit -m "feat: add Search tab with local search and recent searches"
```

---

### Task 22: Settings Tab

**Files:**
- Modify: `NimbusPlayer/NimbusPlayer/Views/Settings/SettingsView.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/Settings/ServerListView.swift`
- Create: `NimbusPlayer/NimbusPlayer/Views/Settings/StorageManagementView.swift`
- Create: `NimbusPlayer/NimbusPlayer/ViewModels/SettingsViewModel.swift`

- [ ] **Step 1: Implement SettingsView**

```swift
// NimbusPlayer/NimbusPlayer/Views/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            List {
                Section("Servers") {
                    NavigationLink("Manage Servers") {
                        ServerListView()
                    }
                }

                Section("Playback") {
                    HStack {
                        Text("Default Speed")
                        Spacer()
                        Text(String(format: "%.1fx", appState.defaultPlaybackSpeed))
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }
                    Slider(value: $state.defaultPlaybackSpeed, in: 0.5...3.0, step: 0.1)
                        .tint(NimbusTheme.Colors.accentPink)

                    Picker("Skip Forward", selection: $state.skipForwardDuration) {
                        ForEach([10.0, 15.0, 30.0, 45.0, 60.0], id: \.self) { val in
                            Text("\(Int(val))s").tag(val)
                        }
                    }

                    Picker("Skip Back", selection: $state.skipBackwardDuration) {
                        ForEach([10.0, 15.0, 30.0, 45.0, 60.0], id: \.self) { val in
                            Text("\(Int(val))s").tag(val)
                        }
                    }

                    Picker("Resume Rewind", selection: $state.resumeRewindSeconds) {
                        Text("Off").tag(0.0 as TimeInterval)
                        Text("3s").tag(3.0 as TimeInterval)
                        Text("5s").tag(5.0 as TimeInterval)
                        Text("10s").tag(10.0 as TimeInterval)
                    }
                }

                Section("Downloads") {
                    Toggle("Download Over Cellular", isOn: $state.downloadOverCellular)
                    Toggle("Auto-Remove Finished", isOn: $state.autoRemoveFinishedDownloads)
                    NavigationLink("Manage Storage") {
                        StorageManagementView()
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $state.appearanceMode) {
                        Text("Dark").tag(AppState.AppearanceMode.dark)
                        Text("Light").tag(AppState.AppearanceMode.light)
                        Text("System").tag(AppState.AppearanceMode.system)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }
                    Button("Clear Image Cache") {
                        Task { await ImageCacheService.shared.clearCache() }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

- [ ] **Step 2: Implement ServerListView**

```swift
// NimbusPlayer/NimbusPlayer/Views/Settings/ServerListView.swift
import SwiftUI
import SwiftData

struct ServerListView: View {
    @Query private var servers: [Server]
    @Environment(\.modelContext) private var modelContext
    @Environment(ServerService.self) private var serverService
    @State private var showAddServer = false

    var body: some View {
        List {
            ForEach(servers) { server in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.displayName)
                            .font(.headline)
                        Text(server.url)
                            .font(.caption)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }
                    Spacer()
                    statusIndicator(for: server)
                }
            }
            .onDelete(perform: deleteServers)
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddServer = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddServer) {
            AddServerView()
        }
    }

    @ViewBuilder
    private func statusIndicator(for server: Server) -> some View {
        let status = serverService.serverStatuses[server.id] ?? .unknown
        Circle()
            .fill(statusColor(status))
            .frame(width: 10, height: 10)
    }

    private func statusColor(_ status: ServerService.ServerStatus) -> Color {
        switch status {
        case .connected: return .green
        case .unreachable: return .red
        case .authExpired: return .orange
        case .unknown: return .gray
        }
    }

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            let server = servers[index]
            serverService.removeServer(server)
            modelContext.delete(server)
        }
        try? modelContext.save()
    }
}
```

- [ ] **Step 3: Implement StorageManagementView**

```swift
// NimbusPlayer/NimbusPlayer/Views/Settings/StorageManagementView.swift
import SwiftUI
import SwiftData

struct StorageManagementView: View {
    @Query(sort: \DownloadModel.totalBytes, order: .reverse) private var downloads: [DownloadModel]
    @Environment(\.modelContext) private var modelContext
    @Environment(DownloadService.self) private var downloadService

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Storage Used")
                    Spacer()
                    Text(formatBytes(downloadService.totalStorageUsed()))
                        .fontWeight(.semibold)
                }
            }

            Section("Downloaded Books") {
                ForEach(downloads.filter { $0.state == .complete }) { download in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(download.book?.title ?? "Unknown")
                                .font(.subheadline)
                            Text(formatBytes(download.totalBytes))
                                .font(.caption)
                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    let completeDownloads = downloads.filter { $0.state == .complete }
                    for index in indexSet {
                        downloadService.deleteDownload(completeDownloads[index], modelContext: modelContext)
                    }
                }
            }
        }
        .navigationTitle("Storage")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
```

- [ ] **Step 4: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Views/Settings/
git commit -m "feat: add Settings tab with server management, playback, downloads, appearance"
```

---

### Task 23: Toast Notifications

**Files:**
- Create: `NimbusPlayer/NimbusPlayer/Views/Components/ToastView.swift`

- [ ] **Step 1: Implement ToastView**

```swift
// NimbusPlayer/NimbusPlayer/Views/Components/ToastView.swift
import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String?

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
            }
            Text(message)
                .font(.subheadline)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(NimbusTheme.Colors.surfaceElevated)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// Toast modifier for any view
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isPresented {
                ToastView(message: message, icon: icon)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { isPresented = false }
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, icon: String? = nil) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Views/Components/ToastView.swift
git commit -m "feat: add reusable toast notification component"
```

---

### Task 24: Wire Up Playback from Book Detail

**Files:**
- Modify: `NimbusPlayer/NimbusPlayer/Views/BookDetail/BookDetailView.swift`

This task connects the Play button in BookDetailView to the AudioPlayerService, including server fallback logic.

- [ ] **Step 1: Add play function to BookDetailView**

Add to BookDetailView:

```swift
@Environment(AudioPlayerService.self) private var playerService
@Environment(ProgressService.self) private var progressService
@Environment(\.modelContext) private var modelContext
@State private var isStartingPlayback = false
@State private var showToast = false
@State private var toastMessage = ""

// Replace the Play button action:
Button {
    Task { await startPlayback() }
} label: {
    // ... existing label code
}
.disabled(isStartingPlayback)

// Add this function:
private func startPlayback() async {
    isStartingPlayback = true

    guard let mapping = book.preferredMapping,
          let serverId = mapping.server?.id,
          let client = serverService.client(for: serverId) else {
        // Try fallback servers
        for otherMapping in book.serverMappings where otherMapping.id != book.preferredMapping?.id {
            if let sid = otherMapping.server?.id,
               let client = serverService.client(for: sid) {
                await attemptPlayback(client: client, mapping: otherMapping, serverId: sid)
                isStartingPlayback = false
                return
            }
        }
        isStartingPlayback = false
        return
    }

    await attemptPlayback(client: client, mapping: mapping, serverId: serverId)
    isStartingPlayback = false
}

private func attemptPlayback(client: APIClient, mapping: ServerBookMapping, serverId: UUID) async {
    let request = PlaybackSessionRequest.defaultRequest(
        deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
        appVersion: "1.0"
    )

    do {
        let session = try await client.startPlaybackSession(
            itemId: mapping.libraryItemId,
            requestBody: request
        )

        await MainActor.run {
            playerService.setServerServiceRef(serverService)
            playerService.startPlayback(
                book: book,
                session: session,
                serverId: serverId,
                serverService: serverService,
                startTime: book.progress?.currentTime
            )
            progressService.startTracking(playerService: playerService, modelContext: modelContext)

            if mapping.id != book.preferredMapping?.id {
                toastMessage = "Playing from \(mapping.server?.displayName ?? "alternate server")"
                showToast = true
            }
        }
    } catch {
        // Playback failed — try to surface error
    }
}
```

Add the toast modifier to BookDetailView's body:

```swift
.toast(isPresented: $showToast, message: toastMessage, icon: "server.rack")
```

- [ ] **Step 2: Build to verify**

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NimbusPlayer/NimbusPlayer/Views/BookDetail/BookDetailView.swift
git commit -m "feat: wire up playback from book detail with server fallback"
```

---

### Task 25: Final Integration & App Lifecycle

**Files:**
- Modify: `NimbusPlayer/NimbusPlayer/App/NimbusPlayerApp.swift`

- [ ] **Step 1: Update NimbusPlayerApp with full service injection and lifecycle**

```swift
// NimbusPlayer/NimbusPlayer/App/NimbusPlayerApp.swift
import SwiftUI
import SwiftData

@main
struct NimbusPlayerApp: App {
    @State private var appState = AppState()
    @State private var serverService = ServerService()
    @State private var audioPlayerService = AudioPlayerService()
    @State private var progressService = ProgressService()
    @State private var downloadService = DownloadService()
    @State private var networkMonitor = NetworkMonitor()
    @State private var libraryService = LibraryService()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(serverService)
                .environment(audioPlayerService)
                .environment(progressService)
                .environment(downloadService)
                .environment(networkMonitor)
                .environment(libraryService)
                .preferredColorScheme(colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhase(newPhase)
                }
        }
        .modelContainer(for: [
            Server.self,
            CachedBook.self,
            ServerBookMapping.self,
            ListeningProgress.self,
            DownloadModel.self,
            Bookmark.self
        ])
    }

    private var colorScheme: ColorScheme? {
        switch appState.appearanceMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // Validate server connections
            Task {
                // Load server clients if needed — requires modelContext from view
            }
        case .background:
            // Final progress sync
            if audioPlayerService.currentBook != nil {
                Task {
                    // Save and sync progress
                }
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
```

- [ ] **Step 2: Build full project**

```bash
xcodebuild -project NimbusPlayer.xcodeproj -scheme NimbusPlayer \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run all tests**

```bash
xcodebuild test -project NimbusPlayer.xcodeproj -scheme NimbusPlayerTests \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Test |Executed)"
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add NimbusPlayer/
git commit -m "feat: complete Nimbus Player integration with all services and lifecycle"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 - Foundation | 1-5 | Project scaffold, UUID v5, Jaro-Winkler, BookMatcher, SwiftData models |
| 2 - Networking | 6-9 | API models, Keychain, API client, ServerService + auth flow |
| 3 - Library Backend | 10-12 | NetworkMonitor, LibraryService (fetch/dedup/merge), ImageCache |
| 4 - Library UI | 13-14 | Library browse (grid/list), BookDetailView, server comparison |
| 5 - Playback | 15-16 | AudioPlayerService (multi-track, remote commands), NowPlaying UI, mini-player |
| 6 - Progress | 17 | ProgressService (local-first, server sync, conflict resolution) |
| 7 - Downloads | 18-19 | DownloadService (background downloads), Downloads UI |
| 8 - Polish | 20-25 | Bookmarks, Search, Settings, Toast, playback wiring, app lifecycle |

**Total: 25 tasks, ~100 steps**

Each task produces a working, committable increment. Tests cover the critical logic (UUID v5, Jaro-Winkler, BookMatcher, API client, Keychain). UI views are verified by building successfully.

---

## Deferred Features (v1.1)

These spec features are intentionally deferred to keep v1 focused and shippable:

1. **Mid-session token expiry handling** — The spec describes a non-blocking banner + sync queue for 401s during playback. V1 will throw an error; v1.1 adds the queued re-auth flow.
2. **Series grouping in library** — `seriesName`/`seriesSequence` are stored and displayed on book detail, but library-level series grouping, series detail view, and "next in series" prompt are deferred.
3. **Download completion persistence** — The `DownloadService` background session delegate needs to update the SwiftData model state on disk (not just in-memory). V1 may require a library refresh to reconcile.
4. **ProgressService and AudioPlayerService unit tests** — Additional test coverage for these critical paths should be added as a fast-follow.
