import SwiftData
import SwiftUI

@main
struct NimbusPlayerApp: App {
    @State private var appState = AppState()
    @State private var audioPlayerService = AudioPlayerService()
    @State private var downloadService = DownloadService()
    @State private var networkMonitor = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(audioPlayerService)
                .environment(downloadService)
                .environment(networkMonitor)
                .preferredColorScheme(appState.appearanceMode.colorScheme)
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
}
