import SwiftData
import SwiftUI

// MARK: - LibraryView

struct LibraryView: View {

    @Environment(ServerService.self) private var serverService
    @Environment(AppState.self) private var appState
    @Environment(LibraryService.self) private var libraryService
    @Environment(ProgressService.self) private var progressService
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(DownloadService.self) private var downloadService
    @Environment(SyncQueueService.self) private var syncQueueService
    @Environment(\.modelContext) private var modelContext

    @Query private var books: [CachedBook]
    @Query(filter: #Predicate<Server> { $0.isActive }) private var servers: [Server]

    @State private var viewModel = LibraryViewModel()
    @State private var isInitialLoad = false
    @State private var hasLoadedOnce = false

    /// When offline, only show downloaded books.
    private var visibleBooks: [CachedBook] {
        if hasUnreachableServers {
            return books.filter { downloadService.isBookDownloaded(bookId: $0.id) }
        }
        return books
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ZStack(alignment: .trailing) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                if hasUnreachableServers {
                                    offlineBanner
                                }
                                if viewModel.groupMode == .allBooks {
                                    let inProgress = viewModel.continueListeningBooks(visibleBooks)
                                    let inProgressIds = Set(inProgress.map(\.id))
                                    continueListeningSection(books: inProgress)
                                    nextInSeriesSection(excludeBookIds: inProgressIds)
                                }
                                libraryContent
                            }
                            .padding(.bottom, 140)
                        }
                        .overlay(alignment: .trailing) {
                            if let letters = activeSectionLetters, letters.count > 1 {
                                SectionIndexView(
                                    letters: letters,
                                    idPrefix: sectionIdPrefix,
                                    scrollProxy: proxy
                                )
                                .padding(.trailing, 2)
                                .padding(.vertical, 60)
                            }
                        }
                    }
                }

                // Loading overlay
                if isInitialLoad {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(NimbusTheme.Colors.accentPink)
                        Text("Loading library...")
                            .font(.subheadline)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NimbusTheme.Colors.backgroundDark.opacity(0.9))
                }
            }
            .background(NimbusTheme.Colors.backgroundDark)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if viewModel.groupMode == .allBooks {
                        sortMenu
                        gridToggleButton
                    }
                    groupModeMenu
                }
            }
            .navigationDestination(for: CachedBook.self) { book in
                BookDetailView(book: book)
            }
            .navigationDestination(for: LibraryViewModel.BookGroup.self) { group in
                GroupDetailView(group: group)
            }
            .refreshable {
                await refreshLibrary()
            }
            .task(id: servers.count) {
                guard !servers.isEmpty else { return }
                guard !hasLoadedOnce else { return }
                hasLoadedOnce = true

                serverService.loadClients(servers: servers)
                await serverService.validateConnections(servers: servers)

                if books.isEmpty {
                    isInitialLoad = true
                    await refreshLibrary()
                    isInitialLoad = false
                } else {
                    // Background refresh on first launch
                    await refreshLibrary()
                }
            }
        }
    }

    // MARK: - Section Index Helpers

    /// Returns the active section letters for the current view, or nil if no index should show.
    private var activeSectionLetters: [String]? {
        if viewModel.groupMode != .allBooks {
            let groups = viewModel.groups(from: visibleBooks)
            let view = GroupListView(groups: groups)
            let letters = view.sectionLetters
            return letters.isEmpty ? nil : letters
        }
        if viewModel.sortOption == .title || viewModel.sortOption == .author {
            let sorted = viewModel.sortedBooks(visibleBooks)
            let letters = sectionLettersForBooks(sorted)
            return letters.isEmpty ? nil : letters
        }
        return nil
    }

    private var sectionIdPrefix: String {
        viewModel.groupMode != .allBooks ? "group-" : "books-"
    }

    private func sectionLettersForBooks(_ books: [CachedBook]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for book in books {
            let key = letterForBook(book)
            if seen.insert(key).inserted {
                result.append(key)
            }
        }
        return result.sorted()
    }

    private func letterForBook(_ book: CachedBook) -> String {
        let text = viewModel.sortOption == .author ? book.author : book.title
        let first = String(text.prefix(1)).uppercased()
        return first.first?.isLetter == true ? first : "#"
    }

    // MARK: - Group Mode Menu

    private var groupModeMenu: some View {
        Menu {
            ForEach(LibraryViewModel.GroupMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation { viewModel.groupMode = mode }
                } label: {
                    Label {
                        Text(mode.displayName)
                    } icon: {
                        if viewModel.groupMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: viewModel.groupMode.icon)
                .font(.body)
                .foregroundStyle(viewModel.groupMode == .allBooks
                    ? NimbusTheme.Colors.textSecondary
                    : NimbusTheme.Colors.accentPink)
        }
    }

    // MARK: - Continue Listening

    @ViewBuilder
    private func continueListeningSection(books inProgressBooks: [CachedBook]) -> some View {
        if !inProgressBooks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Continue Listening")
                    .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(inProgressBooks) { book in
                            NavigationLink(value: book) {
                                ContinueListeningRow(book: book)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    markBookAsComplete(book)
                                } label: {
                                    Label("Mark as Complete", systemImage: "checkmark.circle")
                                }
                                Button(role: .destructive) {
                                    resetBookProgress(book)
                                } label: {
                                    Label("Clear Progress", systemImage: "arrow.counterclockwise")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                }
            }
        }
    }

    // MARK: - Next in Series

    @ViewBuilder
    private func nextInSeriesSection(excludeBookIds: Set<UUID>) -> some View {
        let nextBooks = viewModel.nextInSeriesBooks(visibleBooks, hiddenSeriesIds: appState.hiddenSeriesIds, hiddenSeriesNames: appState.hiddenSeriesNames, excludeBookIds: excludeBookIds)
        if !nextBooks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Next in Series")
                    .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(nextBooks) { book in
                            NavigationLink(value: book) {
                                ContinueListeningRow(book: book)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    dismissSeriesFromContinueListening(book: book)
                                } label: {
                                    Label("Remove Series from Continue Listening", systemImage: "xmark.circle")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                }
            }
        }
    }

    // MARK: - Library Content

    @ViewBuilder
    private var libraryContent: some View {
        if viewModel.groupMode == .allBooks {
            allBooksContent
        } else {
            GroupListView(groups: viewModel.groups(from: visibleBooks))
        }
    }

    // MARK: - All Books

    @ViewBuilder
    private var allBooksContent: some View {
        let sortedBooks = viewModel.sortedBooks(visibleBooks)
        let showSections = viewModel.sortOption == .title || viewModel.sortOption == .author

        if viewModel.isGridView {
            if showSections {
                sectionedGrid(sortedBooks)
            } else {
                plainGrid(sortedBooks)
            }
        } else {
            if showSections {
                sectionedList(sortedBooks)
            } else {
                plainList(sortedBooks)
            }
        }
    }

    // MARK: - Plain Grid/List (no sections)

    private func plainGrid(_ books: [CachedBook]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 20) {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    BookGridItem(book: book)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
    }

    private func plainList(_ books: [CachedBook]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(books) { book in
                NavigationLink(value: book) {
                    BookListRow(book: book)
                }
                .buttonStyle(.plain)

                if book.id != books.last?.id {
                    Divider().background(NimbusTheme.Colors.divider)
                }
            }
        }
        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
    }

    // MARK: - Sectioned Grid/List (with letter headers)

    private func sectionedGrid(_ books: [CachedBook]) -> some View {
        let letters = sectionLettersForBooks(books)
        return LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(letters, id: \.self) { letter in
                let sectionBooks = booksForLetter(letter, in: books)
                if !sectionBooks.isEmpty {
                    sectionHeader(letter)
                        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                        .padding(.top, 8)
                        .id("books-\(letter)")

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 20) {
                        ForEach(sectionBooks) { book in
                            NavigationLink(value: book) {
                                BookGridItem(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                }
            }
        }
    }

    private func sectionedList(_ books: [CachedBook]) -> some View {
        let letters = sectionLettersForBooks(books)
        return LazyVStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                let sectionBooks = booksForLetter(letter, in: books)
                if !sectionBooks.isEmpty {
                    sectionHeader(letter)
                        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                        .id("books-\(letter)")

                    ForEach(sectionBooks) { book in
                        NavigationLink(value: book) {
                            BookListRow(book: book)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)

                        if book.id != sectionBooks.last?.id {
                            Divider().background(NimbusTheme.Colors.divider)
                                .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                        }
                    }
                }
            }
        }
    }

    private func booksForLetter(_ letter: String, in books: [CachedBook]) -> [CachedBook] {
        books.filter { letterForBook($0) == letter }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(LibraryViewModel.SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    HStack {
                        Text(option.displayName)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.subheadline)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
        }
    }

    // MARK: - Grid Toggle

    private var gridToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.isGridView.toggle()
            }
        } label: {
            Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                .font(.subheadline)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
        }
    }

    // MARK: - Helpers

    private var hasUnreachableServers: Bool {
        guard !servers.isEmpty else { return false }
        // Only show offline banner when ALL servers have been checked and none are connected.
        // Treat .unknown (not yet validated) as potentially connected to avoid a flash on startup.
        return servers.allSatisfy { server in
            let status = serverService.serverStatuses[server.id] ?? .unknown
            return status == .unreachable || status == .authExpired
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Server unreachable — downloaded books are still playable")
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(NimbusTheme.Colors.accentPurple.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(NimbusTheme.Colors.textSecondary)
            .tracking(1.2)
    }

    private func refreshLibrary() async {
        // Ensure clients are loaded and check server reachability
        serverService.loadClients(servers: servers)
        await serverService.validateConnections(servers: servers)

        // Pull hidden series list FIRST so the view filters correctly as books load
        await syncHiddenSeries()

        await viewModel.refresh(
            servers: servers,
            serverService: { server in
                serverService.client(for: server.id)
            },
            modelContext: modelContext
        )
        // Set the threshold settings before syncing so pulled progress respects them
        progressService.completionThreshold = appState.completionThreshold
        progressService.completionThresholdMode = appState.completionThresholdMode
        progressService.completionThresholdSeconds = appState.completionThresholdSeconds
        // Sync all progress from servers so "Continue Listening" populates immediately
        await progressService.syncAllProgress(
            servers: servers,
            serverService: serverService,
            modelContext: modelContext
        )

        // Sync bookmarks from server
        await syncBookmarks()

        // Flush any queued actions (bookmarks, series hide, etc.)
        await syncQueueService.flushQueue(modelContext: modelContext, serverService: serverService)
    }

    private func syncBookmarks() async {
        // Build lookup: libraryItemId → CachedBook
        let allBooks: [CachedBook]
        do {
            allBooks = try modelContext.fetch(FetchDescriptor<CachedBook>())
        } catch { return }

        var itemIdToBook: [String: CachedBook] = [:]
        for book in allBooks {
            for mapping in book.serverMappings {
                itemIdToBook[mapping.libraryItemId] = book
            }
        }

        for server in servers where server.isActive {
            guard let client = serverService.client(for: server.id) else { continue }
            guard let user = try? await client.getMe(),
                  let remoteBookmarks = user.bookmarks else { continue }

            for remote in remoteBookmarks {
                guard let book = itemIdToBook[remote.libraryItemId] else { continue }

                // Check if we already have a bookmark at this time (within 1s tolerance)
                let alreadyExists = book.bookmarks.contains { abs($0.timestamp - remote.time) < 1.0 }
                if !alreadyExists {
                    let bookmark = Bookmark(
                        book: book,
                        timestamp: remote.time,
                        note: remote.title
                    )
                    bookmark.dateCreated = Date(timeIntervalSince1970: remote.createdAt / 1000)
                    modelContext.insert(bookmark)
                }
            }
        }

        try? modelContext.save()
    }

    private func syncHiddenSeries() async {
        var allHiddenIds = Set<String>()
        var anyClient: APIClient?

        for server in servers where server.isActive {
            guard let client = serverService.client(for: server.id) else { continue }
            anyClient = client
            guard let user = try? await client.getMe() else { continue }
            if let hidden = user.seriesHideFromContinueListening {
                allHiddenIds.formUnion(hidden)
            }
        }

        // Resolve all hidden series IDs to names.
        // Always resolve all IDs — the name set may be stale or empty from a prior install.
        if let client = anyClient {
            for seriesId in allHiddenIds {
                if let name = try? await client.getSeriesName(seriesId: seriesId) {
                    appState.hiddenSeriesNames.insert(name)
                }
            }
        }

        // Remove names for series that were un-hidden on the server
        let removedIds = appState.hiddenSeriesIds.subtracting(allHiddenIds)
        if !removedIds.isEmpty, let client = anyClient {
            for seriesId in removedIds {
                if let name = try? await client.getSeriesName(seriesId: seriesId) {
                    appState.hiddenSeriesNames.remove(name)
                }
            }
        }

        appState.hiddenSeriesIds = allHiddenIds
    }

    private func dismissSeriesFromContinueListening(book: CachedBook) {
        // Hide locally by name immediately (works even without seriesId)
        if let name = book.seriesName {
            withAnimation {
                appState.hiddenSeriesNames.insert(name)
            }
        }

        if let seriesId = book.seriesId {
            appState.hideSeriesId(seriesId)
            // Queue sync for each server that has this book
            for mapping in book.serverMappings {
                guard let server = mapping.server else { continue }
                syncQueueService.enqueue(
                    action: .seriesHide,
                    payload: SeriesHidePayload(seriesId: seriesId),
                    serverId: server.id,
                    modelContext: modelContext,
                    serverService: serverService
                )
            }
        } else {
            // No seriesId locally — fetch item details to get it, then queue
            Task {
                guard let mapping = book.preferredMapping,
                      let server = mapping.server,
                      let client = serverService.client(for: server.id) else { return }
                guard let details = try? await client.getItemDetails(itemId: mapping.libraryItemId),
                      let seriesId = details.seriesId else { return }
                appState.hideSeriesId(seriesId)
                syncQueueService.enqueue(
                    action: .seriesHide,
                    payload: SeriesHidePayload(seriesId: seriesId),
                    serverId: server.id,
                    modelContext: modelContext,
                    serverService: serverService
                )
            }
        }
    }

    private func markBookAsComplete(_ book: CachedBook) {
        guard let progress = book.progress else { return }
        withAnimation {
            progress.isFinished = true
            progress.needsSync = true
            progress.lastUpdated = Date()
            try? modelContext.save()
        }

        // Queue the isFinished sync to server
        guard let mapping = book.preferredMapping, let server = mapping.server else { return }
        syncQueueService.enqueue(
            action: .markComplete,
            payload: MarkCompletePayload(
                libraryItemId: mapping.libraryItemId,
                progress: progress.progress,
                currentTime: progress.currentTime,
                duration: progress.totalDuration
            ),
            serverId: server.id,
            modelContext: modelContext,
            serverService: serverService
        )
    }

    private func resetBookProgress(_ book: CachedBook) {
        guard let progress = book.progress else { return }
        withAnimation {
            progress.currentTime = 0
            progress.progress = 0
            progress.isFinished = false
            progress.lastUpdated = Date()
            progress.needsSync = true
            try? modelContext.save()
        }
        Task {
            await progressService.flushPendingSyncs(
                modelContext: modelContext,
                serverService: serverService
            )
        }
    }
}
