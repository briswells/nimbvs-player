import SwiftUI
import SwiftData

struct SearchView: View {

    @Query private var books: [CachedBook]
    @Query private var servers: [Server]
    @Environment(ServerService.self) private var serverService
    @Environment(DownloadService.self) private var downloadService
    @State private var viewModel = SearchViewModel()

    private var isOffline: Bool {
        guard !servers.isEmpty else { return false }
        return servers.allSatisfy { serverService.serverStatuses[$0.id] != .connected }
    }

    /// When offline, only show downloaded books in search.
    private var searchableBooks: [CachedBook] {
        if isOffline {
            return books.filter { downloadService.isBookDownloaded(bookId: $0.id) }
        }
        return books
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    recentSearchesView
                } else if viewModel.results.isEmpty && viewModel.seriesResults.isEmpty && !viewModel.isSearching {
                    ContentUnavailableView.search(text: viewModel.query)
                } else {
                    searchResultsList
                }
            }
            .scrollContentBackground(.hidden)
            .background(NimbusTheme.Colors.backgroundDark)
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Title, author, narrator...")
            .onSubmit(of: .search) {
                viewModel.searchImmediate(
                    servers: servers,
                    serverService: serverService,
                    allBooks: searchableBooks
                )
            }
            .onChange(of: viewModel.query) { _, newValue in
                if newValue.isEmpty {
                    viewModel.clearSearch()
                } else {
                    viewModel.searchDebounced(
                        servers: servers,
                        serverService: serverService,
                        allBooks: searchableBooks
                    )
                }
            }
            .navigationDestination(for: CachedBook.self) { book in
                BookDetailView(book: book)
            }
            .navigationDestination(for: LibraryViewModel.BookGroup.self) { group in
                GroupDetailView(group: group)
            }
        }
    }

    // MARK: - Recent Searches

    @ViewBuilder
    private var recentSearchesView: some View {
        if !viewModel.recentSearches.isEmpty {
            List {
                Section("Recent Searches") {
                    ForEach(viewModel.recentSearches, id: \.self) { search in
                        Button {
                            viewModel.query = search
                            viewModel.searchImmediate(
                                servers: servers,
                                serverService: serverService,
                                allBooks: searchableBooks
                            )
                        } label: {
                            Label(search, systemImage: "clock")
                                .foregroundStyle(NimbusTheme.Colors.textPrimary)
                        }
                    }
                }

                Button("Clear Recent Searches", role: .destructive) {
                    viewModel.clearRecentSearches()
                }
            }
        } else {
            ContentUnavailableView(
                "Search Audiobooks",
                systemImage: "magnifyingglass",
                description: Text("Search by title, author, or narrator")
            )
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Series results
                if !viewModel.seriesResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SERIES")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                            .tracking(1.2)
                            .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)

                        ForEach(viewModel.seriesResults) { group in
                            NavigationLink(value: group) {
                                GroupRowView(group: group)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                    }

                    Divider()
                        .background(NimbusTheme.Colors.divider)
                        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                }

                // Book results
                if !viewModel.results.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BOOKS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                            .tracking(1.2)
                            .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)

                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.results) { book in
                                NavigationLink(value: book) {
                                    BookListRow(book: book)
                                }
                                .buttonStyle(.plain)

                                if book.id != viewModel.results.last?.id {
                                    Divider()
                                        .background(NimbusTheme.Colors.divider)
                                }
                            }
                        }
                        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                    }
                }
            }
            .padding(.bottom, 140)
        }
    }
}
