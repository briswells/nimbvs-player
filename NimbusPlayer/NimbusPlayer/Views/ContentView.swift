import SwiftUI

struct ContentView: View {
    // TODO: Wire up onboarding flow later
    var body: some View {
        MainTabView()
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

            // Mini player bar above the tab bar
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

#Preview {
    ContentView()
        .environment(AppState())
        .environment(AudioPlayerService())
        .environment(ServerService())
}
