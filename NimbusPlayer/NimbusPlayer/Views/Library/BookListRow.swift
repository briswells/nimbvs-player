import SwiftUI

// MARK: - CircularProgressView

/// A small circular progress indicator rendered as a trimmed circle arc.
struct CircularProgressView: View {

    // MARK: - Properties

    let progress: Double
    var size: CGFloat = 24
    var lineWidth: CGFloat = 3

    // MARK: - Body

    var body: some View {
        ZStack {
            Circle()
                .stroke(NimbusTheme.Colors.surfaceOverlay, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    NimbusTheme.Colors.accentPink,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - BookListRow

/// Displays a book as a horizontal list row with thumbnail, metadata, and optional progress.
///
/// Shows the cover thumbnail (52 pt), title, author, formatted duration, and a
/// `CircularProgressView` if the book has listening progress.
struct BookListRow: View {

    // MARK: - Properties

    let book: CachedBook
    @Environment(ServerService.self) private var serverService

    private let thumbnailSize: CGFloat = NimbusTheme.Dimensions.coverThumbnailSize

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            coverThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    .lineLimit(1)

                Text(formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
            }

            Spacer()

            if let progress = book.progress, progress.currentTime > 0 {
                CircularProgressView(progress: progress.progress)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Private

    @ViewBuilder
    private var coverThumbnail: some View {
        if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
            CoverImageView(
                itemId: mapping.libraryItemId,
                serverService: serverService,
                serverId: serverId,
                width: thumbnailSize
            )
        } else {
            RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                .fill(NimbusTheme.Colors.surfaceOverlay)
                .frame(width: thumbnailSize, height: thumbnailSize)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }
        }
    }

    private var formattedDuration: String {
        let hours = Int(book.duration) / 3600
        let minutes = (Int(book.duration) % 3600) / 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}
