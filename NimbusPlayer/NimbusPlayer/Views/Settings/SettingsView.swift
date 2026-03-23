import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProgressService.self) private var progressService
    @Environment(ServerService.self) private var serverService
    @Environment(\.modelContext) private var modelContext

    @State private var thresholdDebounce: Task<Void, Never>?

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            List {
                Section("Servers") {
                    NavigationLink("Manage Servers") {
                        ServerListView()
                    }
                    NavigationLink {
                        ListeningStatsView()
                    } label: {
                        Label("Listening Stats", systemImage: "chart.bar.fill")
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

                    Toggle("Auto Sync Progress", isOn: $state.autoSyncProgress)

                    Picker("Completion Threshold", selection: $state.completionThresholdMode) {
                        ForEach(CompletionThresholdMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .onChange(of: appState.completionThresholdMode) { _, _ in
                        scheduleThresholdReapply()
                    }

                    if appState.completionThresholdMode == .percentage {
                        HStack {
                            Text("Mark Complete At")
                            Spacer()
                            Text("\(Int(appState.completionThreshold * 100))%")
                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                        }
                        Slider(value: $state.completionThreshold, in: 0.90...1.0, step: 0.01)
                            .tint(NimbusTheme.Colors.accentPink)
                            .onChange(of: appState.completionThreshold) { _, _ in
                                scheduleThresholdReapply()
                            }
                    } else {
                        HStack {
                            Text("Time Remaining")
                            Spacer()
                            Text(formatThresholdTime(appState.completionThresholdSeconds))
                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(appState.completionThresholdSeconds) },
                                set: { appState.completionThresholdSeconds = Int($0) }
                            ),
                            in: 60...1800,
                            step: 30
                        )
                        .tint(NimbusTheme.Colors.accentPink)
                        .onChange(of: appState.completionThresholdSeconds) { _, _ in
                            scheduleThresholdReapply()
                        }
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

    // MARK: - Helpers

    private func scheduleThresholdReapply() {
        thresholdDebounce?.cancel()
        thresholdDebounce = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await progressService.reapplyCompletionThreshold(
                appState: appState,
                modelContext: modelContext,
                serverService: serverService
            )
        }
    }

    private func formatThresholdTime(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remaining = seconds % 60
            if remaining == 0 {
                return "\(minutes)m"
            }
            return "\(minutes)m \(remaining)s"
        }
        return "\(seconds)s"
    }
}
