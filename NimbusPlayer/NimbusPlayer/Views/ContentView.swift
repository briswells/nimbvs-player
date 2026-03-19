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
                    await serverService.validateConnections(servers: servers)
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
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "book.fill")
                    }

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                DownloadsView()
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .tint(NimbusTheme.Colors.accentPink)

            if playerService.currentBook != nil {
                VStack(spacing: 0) {
                    Spacer()
                    MiniPlayerBar(showNowPlaying: $showNowPlaying)
                        .padding(.bottom, NimbusTheme.Dimensions.tabBarHeight)
                }
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }
}
