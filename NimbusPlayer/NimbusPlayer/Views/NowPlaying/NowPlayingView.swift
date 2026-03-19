import AVKit
import SwiftUI
import SwiftData

// MARK: - AirPlayButton

/// UIViewRepresentable wrapper around `AVRoutePickerView` for AirPlay output selection.
struct AirPlayButton: UIViewRepresentable {

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor(NimbusTheme.Colors.textSecondary)
        picker.activeTintColor = UIColor(NimbusTheme.Colors.accentPink)
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - NowPlayingView

/// Full-screen player view showing cover art, transport controls, chapter navigation,
/// sleep timer, and a scrubber for the currently playing audiobook.
struct NowPlayingView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(ServerService.self) private var serverService
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = NowPlayingViewModel()

    // MARK: - Computed Properties

    private var hasBookmarkAtCurrentTime: Bool {
        guard let book = playerService.currentBook else { return false }
        return book.bookmarks.contains { abs($0.timestamp - playerService.currentTime) < 5 }
    }

    // MARK: - Methods

    private func addBookmark() {
        guard let book = playerService.currentBook else { return }
        let bookmark = Bookmark(book: book, timestamp: playerService.currentTime)
        modelContext.insert(bookmark)
        try? modelContext.save()
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NimbusTheme.Gradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle + AirPlay
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: NimbusTheme.Dimensions.paddingLarge) {
                        coverArt
                        titleSection
                        chapterPill
                        scrubber
                        transportControls
                        bottomActions
                    }
                    .padding(.horizontal, NimbusTheme.Dimensions.paddingLarge)
                    .padding(.bottom, NimbusTheme.Dimensions.paddingLarge)
                }
            }
        }
        .sheet(isPresented: $viewModel.showChapterList) {
            ChapterListSheet()
                .environment(playerService)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showSleepTimer) {
            SleepTimerSheet()
                .environment(playerService)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Drag handle indicator
            Capsule()
                .fill(NimbusTheme.Colors.textTertiary)
                .frame(width: 36, height: 5)

            Spacer()

            AirPlayButton()
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, NimbusTheme.Dimensions.paddingSmall)
        .padding(.top, NimbusTheme.Dimensions.paddingSmall)
    }

    // MARK: - Cover Art

    @ViewBuilder
    private var coverArt: some View {
        if let book = playerService.currentBook,
           let mapping = book.preferredMapping,
           let serverId = mapping.server?.id {
            CoverImageView(
                itemId: mapping.libraryItemId,
                serverService: serverService,
                serverId: serverId,
                width: 200
            )
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .padding(.top, NimbusTheme.Dimensions.paddingMedium)
        } else {
            RoundedRectangle(cornerRadius: NimbusTheme.Dimensions.cornerRadius)
                .fill(NimbusTheme.Colors.surfaceOverlay)
                .frame(width: 200, height: 200)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                .padding(.top, NimbusTheme.Dimensions.paddingMedium)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(playerService.currentBook?.title ?? "")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(NimbusTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(playerService.currentBook?.author ?? "")
                .font(.subheadline)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - Chapter Pill

    @ViewBuilder
    private var chapterPill: some View {
        if let chapter = playerService.currentChapter {
            Button {
                viewModel.showChapterList = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.caption2)
                    Text(chapter.title)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(NimbusTheme.Colors.accentPink)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(NimbusTheme.Colors.accentPink.opacity(0.15))
                )
            }
        }
    }

    // MARK: - Scrubber

    private var scrubber: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: {
                        viewModel.isScrubbing ? viewModel.scrubPosition : playerService.currentTime
                    },
                    set: { newValue in
                        viewModel.isScrubbing = true
                        viewModel.scrubPosition = newValue
                    }
                ),
                in: 0...max(playerService.duration, 1),
                onEditingChanged: { editing in
                    if !editing {
                        playerService.seek(to: viewModel.scrubPosition)
                        viewModel.isScrubbing = false
                    }
                }
            )
            .tint(NimbusTheme.Colors.accentPink)

            HStack {
                Text(viewModel.formatTime(
                    viewModel.isScrubbing ? viewModel.scrubPosition : playerService.currentTime
                ))
                .font(.caption2)
                .foregroundStyle(NimbusTheme.Colors.textTertiary)
                .monospacedDigit()

                Spacer()

                Text(viewModel.formatRemaining(
                    viewModel.isScrubbing ? viewModel.scrubPosition : playerService.currentTime,
                    duration: playerService.duration
                ))
                .font(.caption2)
                .foregroundStyle(NimbusTheme.Colors.textTertiary)
                .monospacedDigit()
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 0) {
            // Speed button
            Button {
                let next = viewModel.nextSpeed(after: playerService.playbackSpeed)
                playerService.setPlaybackSpeed(next)
            } label: {
                Text(viewModel.formatSpeed(playerService.playbackSpeed))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    .frame(width: 50, height: 44)
            }

            Spacer()

            // Rewind 30s
            Button {
                playerService.skipBackward()
            } label: {
                Image(systemName: "gobackward.30")
                    .font(.title2)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    .frame(width: 52, height: 52)
            }

            Spacer()

            // Play/Pause - gradient circle
            Button {
                playerService.togglePlayPause()
            } label: {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(NimbusTheme.Gradients.accent)
                    )
            }

            Spacer()

            // Forward 30s
            Button {
                playerService.skipForward()
            } label: {
                Image(systemName: "goforward.30")
                    .font(.title2)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)
                    .frame(width: 52, height: 52)
            }

            Spacer()

            // Sleep timer
            Button {
                viewModel.showSleepTimer = true
            } label: {
                Image(systemName: playerService.sleepTimerRemaining != nil ? "moon.fill" : "moon")
                    .font(.body)
                    .foregroundStyle(
                        playerService.sleepTimerRemaining != nil
                            ? NimbusTheme.Colors.accentPink
                            : NimbusTheme.Colors.textSecondary
                    )
                    .frame(width: 50, height: 44)
            }
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        HStack(spacing: NimbusTheme.Dimensions.paddingLarge) {
            Spacer()

            // Bookmark
            Button {
                addBookmark()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: hasBookmarkAtCurrentTime ? "bookmark.fill" : "bookmark")
                        .font(.body)
                    Text("Bookmark")
                        .font(.caption2)
                }
                .foregroundStyle(hasBookmarkAtCurrentTime ? NimbusTheme.Colors.accentPink : NimbusTheme.Colors.textSecondary)
            }

            Spacer()

            // Download (placeholder)
            Button {
                // Placeholder — download functionality
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.body)
                    Text("Download")
                        .font(.caption2)
                }
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
            }

            Spacer()

            // Chapters
            Button {
                viewModel.showChapterList = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.body)
                    Text("Chapters")
                        .font(.caption2)
                }
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.top, NimbusTheme.Dimensions.paddingSmall)
    }
}
