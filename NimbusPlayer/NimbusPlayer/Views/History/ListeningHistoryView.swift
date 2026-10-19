import SwiftData
import SwiftUI

struct ListeningHistoryView: View {

    // MARK: - Properties

    let filter: SessionFilter

    @Query private var servers: [Server]
    @Query private var books: [CachedBook]
    @Environment(ServerService.self) private var serverService
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(ProgressService.self) private var progressService
    @Environment(DownloadService.self) private var downloadService
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var rows: [SessionRow] = []
    @State private var page: Int = 0
    @State private var isLoadingInitial = true
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var failedServers: [String] = []
    @State private var pendingRow: SessionRow?
    @State private var showRestoreAlert = false
    @State private var restoreInFlight = false
    @State private var toastMessage = ""
    @State private var showToast = false

    private let service = ListeningHistoryService()

    private var activeServerCount: Int {
        servers.filter(\.isActive).count
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isLoadingInitial {
                loadingState
            } else if rows.isEmpty && !failedServers.isEmpty {
                errorState
            } else if rows.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .background(NimbusTheme.Colors.backgroundDark)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadInitial() }
        .alert("Restore listening position?", isPresented: $showRestoreAlert, presenting: pendingRow) { row in
            Button("Cancel", role: .cancel) { pendingRow = nil }
            Button("Restore & Play", role: .destructive) {
                Task { await restore(row) }
            }
        } message: { row in
            Text("Set \"\(row.bookTitle)\" to \(TimeFormatting.hmmss(row.endTime)) and start playing? Your current progress for this book will be replaced.")
        }
        .toast(isPresented: $showToast, message: toastMessage, icon: "clock.arrow.circlepath")
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(NimbusTheme.Colors.accentPink)
            Text("Loading history…")
                .font(.caption)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Listening Sessions Yet",
            systemImage: "clock.arrow.circlepath",
            description: Text("Your playback history will appear here.")
        )
    }

    private var errorState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Couldn't Load History",
                systemImage: "wifi.slash",
                description: Text("Check your connection and try again.")
            )
            Button("Retry") {
                Task { await loadInitial() }
            }
            .buttonStyle(.borderedProminent)
            .tint(NimbusTheme.Colors.accentPink)
        }
    }

    // MARK: - List

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if !failedServers.isEmpty {
                    partialFailureBanner
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    rowCell(row)
                        .onAppear {
                            if index >= rows.count - 3, hasMore, !isLoadingMore {
                                Task { await loadMore() }
                            }
                        }
                }
                if isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 12)
                }
            }
            .padding(NimbusTheme.Dimensions.paddingMedium)
            .padding(.bottom, 140)
        }
    }

    private var partialFailureBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("Couldn't load from \(failedServers.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
            Spacer()
            Button("Retry") { Task { await loadInitial() } }
                .font(.caption)
        }
        .padding(10)
        .background(NimbusTheme.Colors.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func rowCell(_ row: SessionRow) -> some View {
        Button {
            pendingRow = row
            showRestoreAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(relativeDate(row.startedAt))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    Spacer()
                    Text(TimeFormatting.humanDuration(row.timeListened))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(NimbusTheme.Colors.accentPink)
                }

                if shouldShowBookLine {
                    Text(row.bookTitle)
                        .font(.caption)
                        .foregroundStyle(NimbusTheme.Colors.textPrimary)
                        .lineLimit(1)
                    if !row.bookAuthor.isEmpty {
                        Text(row.bookAuthor)
                            .font(.caption2)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    Text("\(TimeFormatting.hmmss(row.startTime)) → \(TimeFormatting.hmmss(row.endTime))")
                        .font(.caption2)
                        .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    if activeServerCount > 1 {
                        Text("·")
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                        Text(row.serverName)
                            .font(.caption2)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(NimbusTheme.Dimensions.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NimbusTheme.Colors.surfaceOverlay)
            .clipShape(RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(restoreInFlight)
    }

    private var shouldShowBookLine: Bool {
        if case .book = filter { return false }
        return true
    }

    private var navigationTitle: String {
        switch filter {
        case .all: return "Listening History"
        case .book: return "History"
        }
    }

    // MARK: - Loading

    private func loadInitial() async {
        isLoadingInitial = true
        page = 0
        rows = []
        hasMore = true
        failedServers = []
        let result = await service.fetchPage(
            page: 0,
            filter: filter,
            currentSessionId: playerService.sessionId,
            servers: servers,
            serverService: serverService
        )
        rows = result.rows
        hasMore = result.hasMore
        failedServers = result.failedServers
        isLoadingInitial = false
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        let nextPage = page + 1
        let result = await service.fetchPage(
            page: nextPage,
            filter: filter,
            currentSessionId: playerService.sessionId,
            servers: servers,
            serverService: serverService
        )
        // Dedupe against existing ids (servers paginate independently so overlap is possible).
        let existingIds = Set(rows.map(\.id))
        let newRows = result.rows.filter { !existingIds.contains($0.id) }
        rows.append(contentsOf: newRows)
        hasMore = result.hasMore && !newRows.isEmpty
        page = nextPage
        isLoadingMore = false
    }

    // MARK: - Restore

    @MainActor
    private func restore(_ row: SessionRow) async {
        restoreInFlight = true
        defer {
            restoreInFlight = false
            pendingRow = nil
        }

        guard let book = books.first(where: { book in
            book.serverMappings.contains { $0.libraryItemId == row.libraryItemId }
        }) else {
            toastMessage = "Could not find book in library"
            showToast = true
            return
        }

        // Update local progress first so timers don't race. Use the full progress.update
        // path so progress fraction, isFinished, and lastUpdated stay in sync with
        // currentTime (direct assignment would leave progress.progress stale).
        let resolvedDuration = max(row.duration ?? 0, book.duration)
        if let progress = book.progress {
            let duration = progress.totalDuration > 0 ? progress.totalDuration : resolvedDuration
            progress.update(
                currentTime: row.endTime,
                duration: duration,
                completionThreshold: progressService.effectiveThreshold(forDuration: duration)
            )
            // Restoring to an earlier position should un-finish the book.
            if row.endTime < duration {
                progress.isFinished = false
            }
            progress.needsSync = true
        } else {
            let progress = ListeningProgress(
                book: book,
                currentTime: row.endTime,
                totalDuration: resolvedDuration
            )
            progress.needsSync = true
            modelContext.insert(progress)
            book.progress = progress
        }
        try? modelContext.save()

        let result = await PlaybackStarter.start(
            book: book,
            startTime: row.endTime,
            playerService: playerService,
            progressService: progressService,
            serverService: serverService,
            downloadService: downloadService,
            appState: appState,
            modelContext: modelContext
        )

        switch result {
        case .started, .startedOffline, .startedOnAlternateServer:
            dismiss()
        case .failed(let message):
            toastMessage = "Playback failed: \(message)"
            showToast = true
        case .noServerAvailable:
            toastMessage = "No server available and book not downloaded"
            showToast = true
        }
    }

    // MARK: - Formatting

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        if calendar.isDateInToday(date) { return "Today · \(timeOfDay(date))" }
        if calendar.isDateInYesterday(date) { return "Yesterday · \(timeOfDay(date))" }
        if days < 7 { return "\(days) days ago · \(timeOfDay(date))" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func timeOfDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
