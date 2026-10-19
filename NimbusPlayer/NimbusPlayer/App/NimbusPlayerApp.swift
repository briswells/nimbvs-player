import BackgroundTasks
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
    @State private var syncQueueService = SyncQueueService()

    @Environment(\.scenePhase) private var scenePhase

    private static let bgSyncTaskId = "com.nimbvs.player.progressSync"

    init() {
        configureGlobalAppearance()
        registerBackgroundTasks()
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
                .environment(syncQueueService)
                .preferredColorScheme(colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhase(newPhase)
                }
        }
        .modelContainer(Self.sharedModelContainer)
    }

    /// The single SwiftData container for the app. Background sync and scene-phase handling must
    /// use this rather than opening a second container on the same store: objects saved or deleted
    /// through another container aren't reflected in the UI's context, leaving views holding
    /// invalidated models (SwiftData then crashes in `getValue(forKey:)`).
    static let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for:
                Server.self,
                CachedBook.self,
                ServerBookMapping.self,
                ListeningProgress.self,
                DownloadModel.self,
                Bookmark.self,
                PendingSyncAction.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    private var colorScheme: ColorScheme? {
        switch appState.appearanceMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    private func configureGlobalAppearance() {
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

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgSyncTaskId,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: true)
                return
            }
            self.handleBackgroundSync(refreshTask)
        }
    }

    private func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgSyncTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Scheduling can fail if the user has disabled background refresh
        }
    }

    private func handleBackgroundSync(_ task: BGAppRefreshTask) {
        // Schedule the next one
        scheduleBackgroundSync()

        let syncTask = Task { @MainActor in
            let context = Self.sharedModelContainer.mainContext
            let servers = (try? context.fetch(FetchDescriptor<Server>())) ?? []

            serverService.loadClients(servers: servers)
            await progressService.flushPendingSyncs(modelContext: context, serverService: serverService)
            await syncQueueService.flushQueue(modelContext: context, serverService: serverService)
        }

        task.expirationHandler = {
            syncTask.cancel()
        }

        Task {
            _ = await syncTask.result
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Scene Phase

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // Re-validate server connections when returning from background
            Task { @MainActor in
                let context = Self.sharedModelContainer.mainContext
                if let servers = try? context.fetch(FetchDescriptor<Server>()) {
                    serverService.loadClients(servers: servers)
                    await serverService.validateConnections(servers: servers)
                }
            }
        case .background:
            scheduleBackgroundSync()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
