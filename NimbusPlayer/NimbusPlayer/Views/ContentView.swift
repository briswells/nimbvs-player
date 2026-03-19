import SwiftUI

struct ContentView: View {
    // TODO: Wire up onboarding flow later
    var body: some View {
        MainTabView()
    }
}

struct MainTabView: View {
    var body: some View {
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
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
