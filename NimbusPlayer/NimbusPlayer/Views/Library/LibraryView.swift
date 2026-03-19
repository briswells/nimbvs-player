import SwiftData
import SwiftUI

// MARK: - LibraryView

struct LibraryView: View {

    @Environment(ServerService.self) private var serverService
    @Environment(AppState.self) private var appState
    @Environment(LibraryService.self) private var libraryService
    @Environment(\.modelContext) private var modelContext

    @Query private var books: [CachedBook]
    @Query(filter: #Predicate<Server> { $0.isActive }) private var servers: [Server]

    @State private var viewModel = LibraryViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .trailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if viewModel.groupMode == .allBooks {
                                continueListeningSection
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

    // MARK: - Section Index Helpers

    /// Returns the active section letters for the current view, or nil if no index should show.
    private var activeSectionLetters: [String]? {
        if viewModel.groupMode != .allBooks {
            let groups = viewModel.groups(from: books)
            let view = GroupListView(groups: groups)
            let letters = view.sectionLetters
            return letters.isEmpty ? nil : letters
        }
        if viewModel.sortOption == .title || viewModel.sortOption == .author {
            let sorted = viewModel.sortedBooks(books)
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
            GroupListView(groups: viewModel.groups(from: books))
        }
    }

    // MARK: - All Books

    @ViewBuilder
    private var allBooksContent: some View {
        let sortedBooks = viewModel.sortedBooks(books)
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
