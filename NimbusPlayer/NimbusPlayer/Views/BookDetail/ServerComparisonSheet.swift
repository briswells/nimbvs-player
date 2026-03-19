import SwiftUI
import SwiftData

// MARK: - ServerComparisonSheet

/// Presents a list of all servers that host a given book, allowing the user
/// to compare bitrate, format, and file size, and select a preferred server.
struct ServerComparisonSheet: View {

    // MARK: - Properties

    let book: CachedBook

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                ForEach(book.serverMappings, id: \.id) { mapping in
                    Button {
                        selectPreferred(mapping)
                    } label: {
                        serverRow(mapping)
                    }
                    .listRowBackground(NimbusTheme.Colors.surfaceElevated)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NimbusTheme.Colors.backgroundDark)
            .navigationTitle("Available Servers")
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
        .presentationDetents([.medium, .large])
    }

    // MARK: - Row

    private func serverRow(_ mapping: ServerBookMapping) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(mapping.server?.displayName ?? "Unknown Server")
                    .font(.headline)
                    .foregroundStyle(NimbusTheme.Colors.textPrimary)

                HStack(spacing: 12) {
                    if let bitrate = mapping.bitrate {
                        Label("\(bitrate) kbps", systemImage: "waveform")
                            .font(.caption)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }

                    if let format = mapping.format, !format.isEmpty {
                        Label(format, systemImage: "doc")
                            .font(.caption)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }

                    if let fileSize = mapping.fileSize {
                        Label(formatBytes(fileSize), systemImage: "internaldrive")
                            .font(.caption)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            if mapping.isPreferred {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Selection

    private func selectPreferred(_ selected: ServerBookMapping) {
        for mapping in book.serverMappings {
            mapping.isPreferred = (mapping.id == selected.id)
        }
        try? modelContext.save()
    }

    // MARK: - Formatting

    /// Formats a byte count into a human-readable string (e.g. "1.2 GB", "340 MB").
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
