import SwiftData
import SwiftUI

// MARK: - LibraryView

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
                    if viewModel.groupMode == .allBooks {
                        continueListeningSection
                    }
                    libraryContent
                }
                .padding(.bottom, 100)
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
            .task {
                if books.isEmpty {
                    await refreshLibrary()
                }
            }
        }
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

    // MARK: - Continue Listening Section

    @ViewBuilder
    private var continueListeningSection: some View {
        let inProgressBooks = viewModel.continueListeningBooks(books)
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
            let groups = viewModel.groups(from: books)
            if groups.isEmpty {
                ContentUnavailableView(
                    "No Groups",
                    systemImage: "rectangle.stack",
                    description: Text("No books have this metadata.")
                )
            } else {
                GroupListView(groups: groups)
            }
        }
    }

    // MARK: - All Books Content

    @ViewBuilder
    private var allBooksContent: some View {
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(NimbusTheme.Colors.textSecondary)
            .tracking(1.2)
    }

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
