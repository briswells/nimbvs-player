import SwiftUI

// MARK: - BookGridItem

/// Displays a book as a grid cell with cover image, title, and author.
///
/// Intended for use inside a `LazyVGrid` in the library view.
struct BookGridItem: View {

    // MARK: - Properties

    let book: CachedBook
    @Environment(ServerService.self) private var serverService

    private let itemWidth: CGFloat = NimbusTheme.Dimensions.coverGridSize

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            coverImage

            Text(book.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(NimbusTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(book.author)
                .font(.caption2)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: itemWidth)
    }

    // MARK: - Private

    @ViewBuilder
    private var coverImage: some View {
        if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
            CoverImageView(
                itemId: mapping.libraryItemId,
                serverService: serverService,
                serverId: serverId,
                width: itemWidth
            )
        } else {
            RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                .fill(NimbusTheme.Colors.surfaceOverlay)
                .frame(width: itemWidth, height: itemWidth)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }
        }
    }
}
