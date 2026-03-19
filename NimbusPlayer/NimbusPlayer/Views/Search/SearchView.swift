import SwiftUI
import SwiftData

// MARK: - SearchView

/// The Search tab — lets users search their library by title, author, or narrator.
struct SearchView: View {

    // MARK: - Properties

    @Query private var books: [CachedBook]
    @Query private var servers: [Server]
    @Environment(ServerService.self) private var serverService
    @State private var viewModel = SearchViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    if !viewModel.recentSearches.isEmpty {
                        List {
                            Section("Recent Searches") {
                                ForEach(viewModel.recentSearches, id: \.self) { search in
                                    Button {
                                        viewModel.query = search
                                        viewModel.searchImmediate(
                                            servers: servers,
                                            serverService: serverService,
                                            allBooks: books
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
                } else if viewModel.results.isEmpty && !viewModel.isSearching {
                    ContentUnavailableView.search(text: viewModel.query)
                } else {
                    List(viewModel.results) { book in
                        NavigationLink(value: book) {
                            BookListRow(book: book)
                        }
                    }
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
                    allBooks: books
                )
            }
            .onChange(of: viewModel.query) { _, newValue in
                if newValue.isEmpty {
                    viewModel.clearSearch()
                } else {
                    viewModel.searchDebounced(
                        servers: servers,
                        serverService: serverService,
                        allBooks: books
                    )
                }
            }
            .navigationDestination(for: CachedBook.self) { book in
                BookDetailView(book: book)
            }
        }
    }
}
