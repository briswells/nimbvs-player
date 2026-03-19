import SwiftData
import SwiftUI
import UIKit

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

    init() {
        configureGlobalAppearance()
    }

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

    private func configureGlobalAppearance() {
        // Set List/Form backgrounds to our navy theme in dark mode
        let navyBackground = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x1a / 255.0, green: 0x1a / 255.0, blue: 0x2e / 255.0, alpha: 1)
                : .systemGroupedBackground
        }
        let navyRowBackground = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x23 / 255.0, green: 0x23 / 255.0, blue: 0x44 / 255.0, alpha: 1)
                : .secondarySystemGroupedBackground
        }

        UITableView.appearance().backgroundColor = navyBackground
        UICollectionView.appearance().backgroundColor = navyBackground
        UITableViewCell.appearance().backgroundColor = navyRowBackground
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // Validate server connections on foreground
            Task {
                // Server validation happens when views load via their own .task modifiers
            }
        case .background:
            // Final progress sync when going to background
            if audioPlayerService.currentBook != nil {
                Task {
                    // Progress service handles final sync via its own lifecycle
                }
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
