import SwiftUI
import SwiftData

// MARK: - ContinueListeningRow

/// Displays a book in the "Continue Listening" horizontal scroll section.
struct ContinueListeningRow: View {

    let book: CachedBook
    @Environment(ServerService.self) private var serverService
    @Environment(\.modelContext) private var modelContext

    private let itemWidth: CGFloat = NimbusTheme.Dimensions.coverGridSize

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
        .contextMenu {
            Button {
                markAsComplete()
            } label: {
                Label("Mark as Complete", systemImage: "checkmark.circle")
            }
        }
    }

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

    private func markAsComplete() {
        if let progress = book.progress {
            progress.isFinished = true
            progress.needsSync = true
            progress.lastUpdated = Date()
            try? modelContext.save()
        }
    }
}
