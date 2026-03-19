import SwiftData
import SwiftUI

// MARK: - LibraryView

/// The main library browsing view showing a "Continue Listening" section and the full book collection.
///
/// Supports grid and list layouts, multiple sort options, pull-to-refresh, and navigation to book details.
struct LibraryView: View {

    // MARK: - Environment

    @Environment(ServerService.self) private var serverService
    @Environment(AppState.self) private var appState
    @Environment(LibraryService.self) private var libraryService
    @Environment(\.modelContext) private var modelContext

    // MARK: - Queries

    @Query private var books: [CachedBook]
    @Query(filter: #Predicate<Server> { $0.isActive }) private var servers: [Server]

    // MARK: - State

    @State private var viewModel = LibraryViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    continueListeningSection
                    librarySection
                }
                .padding(.bottom, 100)
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: CachedBook.self) { book in
                BookDetailView(book: book)
            }
            .refreshable {
                await refreshLibrary()
            }
            .task {
                if books.isEmpty {
                    await refreshLibrary()
                }
            }
        }
    }

    // MARK: - Continue Listening Section

    @ViewBuilder
    private var continueListeningSection: some View {
        let inProgressBooks = viewModel.continueListeningBooks(books)
        if !inProgressBooks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Continue Listening")

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(inProgressBooks) { book in
                            NavigationLink(value: book) {
                                ContinueListeningRow(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                }
            }
        }
    }

    // MARK: - Library Section

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Library")

                Spacer()

                sortMenu
                gridToggleButton
            }
            .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)

            let sortedBooks = viewModel.sortedBooks(books)

            if viewModel.isGridView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110))],
                    spacing: 20
                ) {
                    ForEach(sortedBooks) { book in
                        NavigationLink(value: book) {
                            BookGridItem(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(sortedBooks) { book in
                        NavigationLink(value: book) {
                            BookListRow(book: book)
                        }
                        .buttonStyle(.plain)

                        if book.id != sortedBooks.last?.id {
                            Divider()
                                .background(NimbusTheme.Colors.divider)
                        }
                    }
                }
                .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
            }
        }
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

    /// Returns a styled uppercase section header label.
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(NimbusTheme.Colors.textSecondary)
            .tracking(1.2)
    }

    /// Refreshes the library by fetching books from all active servers.
    private func refreshLibrary() async {
        await viewModel.refresh(
            servers: servers,
            serverService: { server in
                serverService.client(for: server.id)
            },
            modelContext: modelContext
        )
    }
}

// MARK: - Preview

#Preview {
    LibraryView()
        .environment(ServerService())
        .environment(AppState())
        .environment(LibraryService())
}
