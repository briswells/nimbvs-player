import SwiftUI

// MARK: - MiniPlayerBar

/// A compact player bar displayed above the tab bar when a book is playing.
///
/// Shows a thin gradient progress line at top, cover thumbnail, title,
/// chapter name, and transport controls. Tapping the bar expands to the
/// full-screen `NowPlayingView`.
struct MiniPlayerBar: View {

    // MARK: - Properties

    @Binding var showNowPlaying: Bool

    @Environment(AudioPlayerService.self) private var playerService
    @Environment(ServerService.self) private var serverService

    // MARK: - Body

    var body: some View {
        if let book = playerService.currentBook {
            VStack(spacing: 0) {
                // Thin progress line at top
                progressLine

                HStack(spacing: 12) {
                    // Cover thumbnail
                    coverThumbnail(book: book)

                    // Title and chapter
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                            .lineLimit(1)

                        if let chapter = playerService.currentChapter {
                            Text(chapter.title)
                                .font(.caption)
                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Play/Pause button
                    Button {
                        playerService.togglePlayPause()
                    } label: {
                        Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                            .frame(width: 40, height: 40)
                    }

                    // Skip forward button
                    Button {
                        playerService.skipForward()
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.body)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                .padding(.vertical, 8)
            }
            .background(NimbusTheme.Colors.surfaceElevated)
            .contentShape(Rectangle())
            .onTapGesture {
                showNowPlaying = true
            }
        }
    }

    // MARK: - Progress Line

    private var progressLine: some View {
        GeometryReader { geometry in
            NimbusTheme.Gradients.accent
                .frame(width: geometry.size.width * progress)
        }
        .frame(height: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Cover

    @ViewBuilder
    private func coverThumbnail(book: CachedBook) -> some View {
        if let mapping = book.preferredMapping, let serverId = mapping.server?.id {
            CoverImageView(
                itemId: mapping.libraryItemId,
                serverService: serverService,
                serverId: serverId,
                width: 40
            )
            .id(book.id)
        } else {
            RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.smallCornerRadius)
                .fill(NimbusTheme.Colors.surfaceOverlay)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(.caption)
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }
        }
    }

    // MARK: - Computed

    private var progress: Double {
        guard playerService.duration > 0 else { return 0 }
        return min(max(playerService.currentTime / playerService.duration, 0), 1)
    }
}
