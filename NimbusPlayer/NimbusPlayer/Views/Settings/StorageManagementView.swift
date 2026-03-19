import SwiftUI
import SwiftData

struct StorageManagementView: View {
    @Query(sort: \DownloadModel.totalBytes, order: .reverse) private var downloads: [DownloadModel]
    @Environment(\.modelContext) private var modelContext
    @Environment(DownloadService.self) private var downloadService

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total Storage Used")
                    Spacer()
                    Text(formatBytes(downloadService.totalStorageUsed()))
                        .fontWeight(.semibold)
                }
            }

            Section("Downloaded Books") {
                ForEach(downloads.filter { $0.state == .complete }) { download in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(download.book?.title ?? "Unknown")
                                .font(.subheadline)
                            Text(formatBytes(download.totalBytes))
                                .font(.caption)
                                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    let completeDownloads = downloads.filter { $0.state == .complete }
                    for index in indexSet {
                        downloadService.deleteDownload(completeDownloads[index], modelContext: modelContext)
                    }
                }
            }
        }
        .navigationTitle("Storage")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
