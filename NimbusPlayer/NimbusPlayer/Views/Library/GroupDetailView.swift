import SwiftUI

/// Detail view showing all books within a group (series, author, or narrator).
struct GroupDetailView: View {
    let group: LibraryViewModel.BookGroup
    @Environment(ServerService.self) private var serverService

    private var isSeries: Bool { group.id.hasPrefix("series:") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(NimbusTheme.Colors.textPrimary)

                    Text("\(group.books.count) book\(group.books.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(NimbusTheme.Colors.textSecondary)
                }
                .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)

                // Book list
                LazyVStack(spacing: 0) {
                    ForEach(group.books) { book in
                        NavigationLink(value: book) {
                            GroupBookRow(book: book, showSequence: isSeries)
                        }
                        .buttonStyle(.plain)

                        if book.id != group.books.last?.id {
                            Divider()
                                .background(NimbusTheme.Colors.divider)
                        }
                    }
                }
                .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
            }
            .padding(.bottom, 100)
        }
        .background(NimbusTheme.Colors.backgroundDark)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CachedBook.self) { book in
            BookDetailView(book: book)
        }
    }
}

/// A row within the group detail view showing sequence, cover, title, and progress.
struct GroupBookRow: View {
    let book: CachedBook
    var showSequence: Bool = true
    @Environment(ServerService.self) private var serverService

    var body: some View {
        HStack(spacing: 12) {
            // Sequence badge (series only)
            if showSequence, let seq = book.seriesSequence, !seq.isEmpty {
                Text("#\(seq)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                    .frame(width: 36)
            }

            // Cover
            if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
                CoverImageView(
                    itemId: mapping.libraryItemId,
                    serverService: serverService,
                    serverId: serverId,
                    width: 44
                )
            }

            // Title + Author
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
            }

            Spacer()

            // Progress
            if let progress = book.progress, progress.currentTime > 0 {
                CircularProgressView(progress: progress.progress)
            }
        }
        .padding(.vertical, 8)
    }

    private var formattedDuration: String {
        let hours = Int(book.duration) / 3600
        let minutes = (Int(book.duration) % 3600) / 60
        if hours > 0 { return "\(hours) hr \(minutes) min" }
        return "\(minutes) min"
    }
}
