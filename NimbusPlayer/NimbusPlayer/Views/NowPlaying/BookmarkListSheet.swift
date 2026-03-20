import SwiftUI
import SwiftData

struct BookmarkListSheet: View {
    let playerService: AudioPlayerService
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    private var bookmarks: [Bookmark] {
        (playerService.currentBook?.bookmarks ?? [])
            .sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Tap the bookmark button to save your place.")
                    )
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            Button {
                                playerService.seek(to: bookmark.timestamp)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption)
                                        .foregroundStyle(NimbusTheme.Colors.accentPink)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatTimestamp(bookmark.timestamp))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                                            .monospacedDigit()

                                        if let note = bookmark.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                                                .lineLimit(1)
                                        }

                                        Text(formatDate(bookmark.dateCreated))
                                            .font(.caption2)
                                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                                    }

                                    Spacer()

                                    // Show chapter name if available
                                    if let chapter = chapterAt(bookmark.timestamp) {
                                        Text(chapter.title)
                                            .font(.caption2)
                                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                                            .lineLimit(1)
                                            .frame(maxWidth: 100, alignment: .trailing)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteBookmarks)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(NimbusTheme.Colors.backgroundDark)
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NimbusTheme.Colors.accentPink)
                }
            }
        }
    }

    private func deleteBookmarks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bookmarks[index])
        }
        try? modelContext.save()
    }

    private func chapterAt(_ timestamp: TimeInterval) -> ChapterResponse? {
        playerService.chapters.last { $0.start <= timestamp }
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
