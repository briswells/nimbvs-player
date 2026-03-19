import SwiftUI
import SwiftData

// MARK: - BookDetailView

/// Full-screen detail view for an audiobook, showing cover art, metadata,
/// progress, playback controls, description, and a chapter list.
struct BookDetailView: View {

    // MARK: - Properties

    let book: CachedBook

    @Environment(ServerService.self) private var serverService
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(ProgressService.self) private var progressService
    @Environment(DownloadService.self) private var downloadService
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BookDetailViewModel()
    @State private var showServerComparison = false
    @State private var isStartingPlayback = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showSyncPrompt = false
    @State private var pendingRemoteProgress: MediaProgressResponse?
    @State private var showNowPlaying = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: NimbusTheme.Dimensions.paddingLarge) {
                coverSection
                metadataSection
                statsSection
                progressSection
                actionButtons
                descriptionSection
                chapterListSection
            }
            .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
            .padding(.bottom, 140)
        }
        .background(NimbusTheme.Gradients.background)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showServerComparison) {
            ServerComparisonSheet(book: book)
        }
        .task {
            await viewModel.loadDetails(book: book, serverService: serverService)
            await checkRemoteProgress()
        }
        .toast(isPresented: $showToast, message: toastMessage, icon: "server.rack")
        .alert("Sync Progress from Other Device?", isPresented: $showSyncPrompt) {
            Button("Sync") {
                if let remote = pendingRemoteProgress {
                    progressService.applyRemoteProgress(remote, to: book, modelContext: modelContext)
                    toastMessage = "Progress synced"
                    showToast = true
                }
                pendingRemoteProgress = nil
            }
            Button("Keep Local", role: .cancel) {
                pendingRemoteProgress = nil
            }
        } message: {
            if let remote = pendingRemoteProgress {
                let pct = Int(remote.progress * 100)
                let mins = Int(remote.currentTime) / 60
                Text("Another device has progress at \(pct)% (\(mins) min). Use that position?")
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }

    // MARK: - Cover Section

    private var coverSection: some View {
        VStack {
            if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
                CoverImageView(
                    itemId: mapping.libraryItemId,
                    serverService: serverService,
                    serverId: serverId,
                    width: NimbusTheme.Dimensions.coverDetailSize
                )
                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
            } else {
                RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                    .fill(NimbusTheme.Colors.surfaceOverlay)
                    .frame(
                        width: NimbusTheme.Dimensions.coverDetailSize,
                        height: NimbusTheme.Dimensions.coverDetailSize
                    )
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .font(.largeTitle)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    }
            }
        }
        .padding(.top, NimbusTheme.Dimensions.paddingMedium)
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(spacing: 6) {
            Text(book.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(NimbusTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(book.author)
                .font(.subheadline)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)

            if let narrator = book.narrator, !narrator.isEmpty {
                Text("Narrated by \(narrator)")
                    .font(.caption)
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
            }

            if let seriesName = book.seriesName, !seriesName.isEmpty {
                seriesBadge(name: seriesName, sequence: book.seriesSequence)
            }
        }
    }

    private func seriesBadge(name: String, sequence: String?) -> some View {
        let label = sequence != nil ? "\(name) #\(sequence!)" : name
        return Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(NimbusTheme.Colors.accentPink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(NimbusTheme.Colors.accentPink.opacity(0.15))
            )
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: NimbusTheme.Dimensions.paddingMedium) {
            statItem(
                icon: "clock",
                value: viewModel.formatDuration(book.duration)
            )

            if let progress = book.progress, progress.currentTime > 0 {
                statItem(
                    icon: "percent",
                    value: "\(Int(progress.progress * 100))%"
                )
            }

            if book.isMultiServer {
                Button {
                    showServerComparison = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack")
                            .font(.caption)
                        Text("\(book.serverMappings.count) servers")
                            .font(.caption)
                    }
                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(NimbusTheme.Colors.surfaceOverlay)
                    )
                }
            }
        }
    }

    private func statItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(NimbusTheme.Colors.textTertiary)
            Text(value)
                .font(.caption)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private var progressSection: some View {
        if let progress = book.progress, progress.currentTime > 0, !progress.isFinished {
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(NimbusTheme.Colors.surfaceOverlay)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(NimbusTheme.Gradients.accent)
                            .frame(width: geometry.size.width * CGFloat(progress.progress), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text(viewModel.formatTimestamp(progress.currentTime))
                        .font(.caption2)
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    Spacer()
                    Text(viewModel.formatTimestamp(book.duration))
                        .font(.caption2)
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, NimbusTheme.Dimensions.paddingSmall)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: NimbusTheme.Dimensions.paddingMedium) {
            // Play / Continue button
            Button {
                if playerService.currentBook?.id == book.id {
                    showNowPlaying = true
                } else {
                    Task { await startPlayback() }
                }
            } label: {
                HStack(spacing: 8) {
                    if isStartingPlayback || playerService.isBuffering {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: playButtonIcon)
                            .font(.body.weight(.semibold))
                    }
                    Text(isStartingPlayback ? "Loading..." : playButtonLabel)
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(NimbusTheme.Gradients.accent)
                .clipShape(RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.cornerRadius))
            }
            .disabled(isStartingPlayback)

            // Download button
            Button {
                Task { await startDownload() }
            } label: {
                Group {
                    if isBookDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    } else if isDownloading {
                        ProgressView()
                            .tint(NimbusTheme.Colors.accentPink)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }
                }
                .frame(width: 50, height: 50)
                .background(NimbusTheme.Colors.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.cornerRadius))
            }
            .disabled(isBookDownloaded || isDownloading)
        }
    }

    private var playButtonIcon: String {
        if let progress = book.progress, progress.currentTime > 0, !progress.isFinished {
            return "play.fill"
        }
        return "play.fill"
    }

    private var playButtonLabel: String {
        if let progress = book.progress, progress.currentTime > 0, !progress.isFinished {
            return "Continue"
        } else if let progress = book.progress, progress.isFinished {
            return "Play Again"
        }
        return "Play"
    }

    // MARK: - Description Section

    @ViewBuilder
    private var descriptionSection: some View {
        if let description = book.bookDescription, !description.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Chapter List Section

    @ViewBuilder
    private var chapterListSection: some View {
        if !viewModel.chapters.isEmpty {
            VStack(alignment: .leading, spacing: NimbusTheme.Dimensions.paddingSmall) {
                Text("Chapters")
                    .font(.headline)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)

                ForEach(viewModel.chapters, id: \.id) { chapter in
                    chapterRow(chapter)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if viewModel.isLoadingDetails {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(NimbusTheme.Colors.textTertiary)
                Text("Loading chapters...")
                    .font(.caption)
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, NimbusTheme.Dimensions.paddingLarge)
        }
    }

    private func chapterRow(_ chapter: ChapterResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(.subheadline)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(viewModel.formatTimestamp(chapter.start))
                    .font(.caption2)
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
            }

            Spacer()

            Text(viewModel.formatDuration(chapter.end - chapter.start))
                .font(.caption)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, NimbusTheme.Dimensions.paddingSmall)
        .background(NimbusTheme.Colors.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius))
    }

    // MARK: - Download

    private var isBookDownloaded: Bool {
        downloadService.isBookDownloaded(bookId: book.id)
    }

    private var isDownloading: Bool {
        book.downloads.contains { $0.state == .downloading || $0.state == .queued }
    }

    private func startDownload() async {
        do {
            try await downloadService.startDownload(
                book: book,
                serverService: serverService,
                networkMonitor: networkMonitor,
                allowCellular: appState.downloadOverCellular,
                modelContext: modelContext
            )
            toastMessage = "Download started"
            showToast = true
        } catch {
            toastMessage = error.localizedDescription
            showToast = true
        }
    }

    // MARK: - Remote Progress Check

    private func checkRemoteProgress() async {
        guard let remote = await progressService.fetchRemoteProgress(
            book: book,
            serverService: serverService
        ) else { return }

        let localTime = book.progress?.currentTime ?? 0
        let localUpdate = book.progress?.lastUpdated ?? .distantPast

        if localTime == 0 && !remote.isFinished && remote.currentTime > 0 {
            // No local progress — auto-sync from remote
            progressService.applyRemoteProgress(remote, to: book, modelContext: modelContext)
            toastMessage = "Progress synced from server"
            showToast = true
        } else if localTime > 0 {
            // Local progress exists — check if remote is newer
            // lastUpdate is in milliseconds
            let remoteDate = Date(timeIntervalSince1970: remote.lastUpdate / 1000)
            if remoteDate > localUpdate && abs(remote.currentTime - localTime) > 30 {
                pendingRemoteProgress = remote
                showSyncPrompt = true
            }
        }
    }

    // MARK: - Playback

    private func startPlayback() async {
        isStartingPlayback = true

        // Always prefer local files if downloaded — faster and works offline
        if isBookDownloaded {
            playOffline()
            isStartingPlayback = false
            return
        }

        guard let mapping = book.preferredMapping,
              let serverId = mapping.server?.id,
              let client = serverService.client(for: serverId) else {
            toastMessage = "No server available and book not downloaded"
            showToast = true
            isStartingPlayback = false
            return
        }

        await attemptPlayback(client: client, mapping: mapping, serverId: serverId)
        isStartingPlayback = false
    }

    private func playOffline() {
        playerService.startOfflinePlayback(
            book: book,
            downloadService: downloadService,
            startTime: book.progress?.currentTime
        )
        toastMessage = "Playing offline"
        showToast = true
    }

    private func attemptPlayback(client: APIClient, mapping: ServerBookMapping, serverId: UUID) async {
        let request = PlaybackSessionRequest.defaultRequest(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            appVersion: "1.0"
        )

        do {
            let session = try await client.startPlaybackSession(
                itemId: mapping.libraryItemId,
                requestBody: request
            )

            await MainActor.run {
                playerService.setServerServiceRef(serverService)
                playerService.startPlayback(
                    book: book,
                    session: session,
                    serverId: serverId,
                    serverService: serverService,
                    startTime: book.progress?.currentTime
                )
                progressService.startTracking(playerService: playerService, modelContext: modelContext)

                if mapping.id != book.preferredMapping?.id {
                    toastMessage = "Playing from \(mapping.server?.displayName ?? "alternate server")"
                    showToast = true
                }
            }
        } catch {
            // Server failed — fall back to offline if downloaded
            if isBookDownloaded {
                await MainActor.run { playOffline() }
            } else {
                await MainActor.run {
                    toastMessage = "Playback failed: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }
}
