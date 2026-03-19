import SwiftUI
import SwiftData

struct ServerListView: View {
    @Query private var servers: [Server]
    @Environment(\.modelContext) private var modelContext
    @Environment(ServerService.self) private var serverService
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
            serverService.removeServer(server)
            modelContext.delete(server)
        }
        try? modelContext.save()
    }
}
