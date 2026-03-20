import SwiftUI
import SwiftData

struct DownloadsView: View {
    @Query private var downloads: [DownloadModel]
    @Environment(\.modelContext) private var modelContext
    @Environment(DownloadService.self) private var downloadService
    @State private var viewModel = DownloadsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if downloads.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Downloaded audiobooks will appear here for offline listening.")
                    )
                } else {
                    List {
                        Section {
                            HStack {
                                Text("Storage Used")
                                Spacer()
                                Text(viewModel.formatBytes(downloadService.totalStorageUsed()))
                                    .foregroundStyle(NimbusTheme.Colors.textSecondary)
                            }
                        }

                        Section("Downloads") {
                            ForEach(downloads) { download in
                                DownloadRow(download: download, viewModel: viewModel)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    downloadService.deleteDownload(downloads[index], modelContext: modelContext)
                                }
                            }
                        }
                    }
                }
            }
            .contentMargins(.bottom, 140)
            .scrollContentBackground(.hidden)
            .background(NimbusTheme.Colors.backgroundDark)
            .navigationTitle("Downloads")
        }
    }
}

struct DownloadRow: View {
    let download: DownloadModel
    let viewModel: DownloadsViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(download.book?.title ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(download.book?.author ?? "")
                    .font(.caption)
                    .foregroundStyle(NimbusTheme.Colors.textSecondary)

                HStack(spacing: 8) {
                    Text(stateLabel)
                        .font(.caption2)
                        .foregroundStyle(stateColor)

                    if download.state == .downloading {
                        Text(viewModel.formatBytes(download.downloadedBytes) + " / " + viewModel.formatBytes(download.totalBytes))
                            .font(.caption2)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    } else if download.state == .complete {
                        Text(viewModel.formatBytes(download.totalBytes))
                            .font(.caption2)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            if download.state == .downloading {
                ProgressView(value: download.progressFraction)
                    .frame(width: 40)
                    .tint(NimbusTheme.Colors.accentPink)
            } else if download.state == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if download.state == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private var stateLabel: String {
        switch download.state {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .complete: return "Downloaded"
        case .failed: return download.errorMessage ?? "Failed"
        }
    }

    private var stateColor: Color {
        switch download.state {
        case .complete: return .green
        case .failed: return .red
        case .downloading: return NimbusTheme.Colors.accentPink
        default: return NimbusTheme.Colors.textTertiary
        }
    }
}
