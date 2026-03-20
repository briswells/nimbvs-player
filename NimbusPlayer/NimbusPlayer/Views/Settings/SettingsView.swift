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
                        ForEach([10, 15, 30, 45, 60], id: \.self) { val in
                            Text("\(val)s").tag(val)
                        }
                    }

                    Picker("Skip Back", selection: $state.skipBackwardDuration) {
                        ForEach([10, 15, 30, 45, 60], id: \.self) { val in
                            Text("\(val)s").tag(val)
                        }
                    }

                    Picker("Resume Rewind", selection: $state.resumeRewindSeconds) {
                        Text("Off").tag(0)
                        Text("3s").tag(3)
                        Text("5s").tag(5)
                        Text("10s").tag(10)
                    }

                    HStack {
                        Text("Completion Threshold")
                        Spacer()
                        Text("\(Int(appState.completionThreshold * 100))%")
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }
                    Slider(value: $state.completionThreshold, in: 0.90...1.0, step: 0.01)
                        .tint(NimbusTheme.Colors.accentPink)
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
                        Text("Dark").tag(AppearanceMode.dark)
                        Text("Light").tag(AppearanceMode.light)
                        Text("System").tag(AppearanceMode.system)
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
            .contentMargins(.bottom, 140)
            .scrollContentBackground(.hidden)
            .background(NimbusTheme.Colors.backgroundGrouped)
            .navigationTitle("Settings")
        }
    }
}
