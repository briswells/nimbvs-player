import SwiftUI

/// A single row in the group list, showing a cover thumbnail, group name, and book count.
struct GroupRowView: View {
    let group: LibraryViewModel.BookGroup
    @Environment(ServerService.self) private var serverService

    var body: some View {
        HStack(spacing: 12) {
            coverThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    .lineLimit(2)

                Text("\(group.books.count) book\(group.books.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(NimbusTheme.Colors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(NimbusTheme.Colors.textTertiary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        if let book = group.books.first,
           let mapping = book.preferredMapping,
           let serverId = mapping.server?.id {
            CoverImageView(
                itemId: mapping.libraryItemId,
                serverService: serverService,
                serverId: serverId,
                width: NimbusTheme.Dimensions.coverThumbnailSize
            )
        } else {
            RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                .fill(NimbusTheme.Colors.surfaceOverlay)
                .frame(width: NimbusTheme.Dimensions.coverThumbnailSize, height: NimbusTheme.Dimensions.coverThumbnailSize)
                .overlay {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }
        }
    }
}
