import SwiftUI

// MARK: - ContinueListeningRow

/// Displays a book in the "Continue Listening" horizontal scroll section.
///
/// Shows the cover image, title, a progress bar, and a percentage-complete label.
/// Tapping navigates to the book's detail view.
struct ContinueListeningRow: View {

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

            if let progress = book.progress {
                ProgressBar(progress: progress.progress, height: 3)

                Text("\(Int(progress.progress * 100))% complete")
                    .font(.caption2)
                    .foregroundStyle(NimbusTheme.Colors.textSecondary)
            }
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
