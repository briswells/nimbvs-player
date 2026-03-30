import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var servers: [Server]
    @Environment(ServerService.self) private var serverService
    @State private var showOnboarding = false

    var body: some View {
        MainTabView()
            .task {
                if !servers.isEmpty {
                    serverService.loadClients(servers: servers)
                    // Don't block — LibraryView handles validation and sync
                }
            }
            .onAppear {
                if servers.isEmpty {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding) {
                AddServerView(isOnboarding: true) {
                    showOnboarding = false
                }
            }
    }
}

struct MainTabView: View {

    @State private var showNowPlaying = false
    @Environment(AudioPlayerService.self) private var playerService

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                Tab("Library", systemImage: "book.fill") {
                    LibraryView()
                }

                Tab("Search", systemImage: "magnifyingglass") {
                    SearchView()
                }

                Tab("Downloads", systemImage: "arrow.down.circle.fill") {
                    DownloadsView()
                }

                Tab("Settings", systemImage: "gearshape.fill") {
                    SettingsView()
                }
            }
            .tint(NimbusTheme.Colors.accentPink)

            if playerService.currentBook != nil {
                VStack(spacing: 0) {
                    Spacer()
                    MiniPlayerBar(showNowPlaying: $showNowPlaying)
                        .padding(.horizontal, 10)
                        .padding(.bottom, NimbusTheme.Dimensions.tabBarHeight + 2)
                }
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
        .onChange(of: playerService.didFinishBook) { _, finished in
            guard finished else { return }
            // Dismiss the full-screen player first, then clean up after it animates out
            if showNowPlaying {
                showNowPlaying = false
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    playerService.stop()
                }
            } else {
                playerService.stop()
            }
        }
        .onChange(of: playerService.currentBook == nil) { _, isNil in
            // Safety: if currentBook is cleared while player is showing, dismiss it
            if isNil && showNowPlaying {
                showNowPlaying = false
            }
        }
    }
}
