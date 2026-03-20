import SwiftUI
import SwiftData

struct ServerListView: View {
    @Query private var servers: [Server]
    @Environment(\.modelContext) private var modelContext
    @Environment(ServerService.self) private var serverService
    @Environment(DownloadService.self) private var downloadService
    @State private var showAddServer = false

    var body: some View {
        List {
            ForEach(servers) { server in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.displayName)
                            .font(.headline)
                        Text(server.url)
                            .font(.caption)
                            .foregroundStyle(NimbusTheme.Colors.textSecondary)
                    }
                    Spacer()
                    statusIndicator(for: server)
                }
            }
            .onDelete(perform: deleteServers)
        }
        .scrollContentBackground(.hidden)
        .background(NimbusTheme.Colors.backgroundGrouped)
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddServer = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddServer) {
            AddServerView()
        }
    }

    @ViewBuilder
    private func statusIndicator(for server: Server) -> some View {
        let status = serverService.serverStatuses[server.id] ?? .unknown
        Circle()
            .fill(statusColor(status))
            .frame(width: 10, height: 10)
    }

    private func statusColor(_ status: ServerService.ServerStatus) -> Color {
        switch status {
        case .connected: return .green
        case .unreachable: return .red
        case .authExpired: return .orange
        case .unknown: return .gray
        }
    }

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            let server = servers[index]

            // Find all books that ONLY exist on this server (no other mappings)
            let allMappings = server.bookMappings
            for mapping in allMappings {
                if let book = mapping.book {
                    // Remove downloaded files for this book
                    downloadService.removeAllFiles(bookId: book.id)

                    // If this is the only server mapping, delete the whole book
                    if book.serverMappings.count <= 1 {
                        // Delete related models
                        if let progress = book.progress {
                            modelContext.delete(progress)
                        }
                        for bookmark in book.bookmarks {
                            modelContext.delete(bookmark)
                        }
                        for download in book.downloads {
                            modelContext.delete(download)
                        }
                        modelContext.delete(book)
                    }
                }
                modelContext.delete(mapping)
            }

            serverService.removeServer(server)
            modelContext.delete(server)
        }
        try? modelContext.save()
    }
}
