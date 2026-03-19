import SwiftUI

@main
struct NimbusPlayerApp: App {
    @State private var appState = AppState()

    // TODO: Add SwiftData modelContainer in Task 5
    // Models: Server, CachedBook, ServerBookMapping, ListeningProgress, DownloadModel, Bookmark

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
    }
}
