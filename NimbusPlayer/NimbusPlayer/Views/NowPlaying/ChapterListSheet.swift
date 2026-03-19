import SwiftUI

// MARK: - ChapterListSheet

/// A sheet presenting the chapter list for the currently playing book.
///
/// The active chapter is highlighted with the accent pink colour and a
/// speaker icon. Tapping a chapter seeks to its start and dismisses the sheet.
struct ChapterListSheet: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayerService.self) private var playerService

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                ForEach(playerService.chapters, id: \.id) { chapter in
                    chapterRow(chapter)
                        .listRowBackground(NimbusTheme.Colors.surfaceElevated)
                        .listRowSeparatorTint(NimbusTheme.Colors.divider)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NimbusTheme.Colors.backgroundDark)
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                }
            }
        }
    }

    // MARK: - Chapter Row

    private func chapterRow(_ chapter: ChapterResponse) -> some View {
        let isCurrent = playerService.currentChapter?.id == chapter.id

        return Button {
            playerService.seekToChapter(chapter)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // Speaker icon for current chapter
                if isCurrent {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(NimbusTheme.Colors.accentPink)
                        .frame(width: 20)
                } else {
                    Text("\(chapter.id)")
                        .font(.caption)
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                        .frame(width: 20)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title)
                        .font(.subheadline)
                        .fontWeight(isCurrent ? .semibold : .regular)
                        .foregroundStyle(
                            isCurrent
                                ? NimbusTheme.Colors.accentPink
                                : NimbusTheme.Colors.textPrimary
                        )
                        .lineLimit(2)

                    Text(formatDuration(chapter.end - chapter.start))
                        .font(.caption2)
                        .foregroundStyle(NimbusTheme.Colors.textTertiary)
                }

                Spacer()

                if isCurrent {
                    // Show elapsed within chapter
                    let elapsed = playerService.currentTime - chapter.start
                    let total = chapter.end - chapter.start
                    Text("\(formatDuration(elapsed)) / \(formatDuration(total))")
                        .font(.caption2)
                        .foregroundStyle(NimbusTheme.Colors.textSecondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
