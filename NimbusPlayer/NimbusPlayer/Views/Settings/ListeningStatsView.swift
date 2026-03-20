import SwiftUI
import SwiftData

struct ListeningStatsView: View {
    @Environment(ServerService.self) private var serverService
    @Query private var servers: [Server]

    @State private var stats: ListeningStatsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(NimbusTheme.Colors.accentPink)
                    Text("Loading stats...")
                        .font(.caption)
                        .foregroundStyle(NimbusTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let stats {
                ScrollView {
                    VStack(spacing: 20) {
                        overviewSection(stats)
                        topBooksSection(stats)
                    }
                    .padding(NimbusTheme.Dimensions.paddingMedium)
                    .padding(.bottom, 140)
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Couldn't Load Stats",
                    systemImage: "chart.bar.xaxis",
                    description: Text(errorMessage)
                )
            }
        }
        .background(NimbusTheme.Colors.backgroundDark)
        .navigationTitle("Listening Stats")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadStats()
        }
    }

    // MARK: - Overview

    private func overviewSection(_ stats: ListeningStatsResponse) -> some View {
        VStack(spacing: 16) {
            // Total time
            VStack(spacing: 4) {
                Text("Total Listening Time")
                    .font(.caption)
                    .foregroundStyle(NimbusTheme.Colors.textSecondary)
                Text(formatHours(stats.totalTime))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(NimbusTheme.Colors.accentPink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(NimbusTheme.Colors.surfaceOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Today + Books
            HStack(spacing: 12) {
                statCard(
                    title: "Today",
                    value: formatHours(stats.today ?? 0),
                    icon: "calendar"
                )
                statCard(
                    title: "Books",
                    value: "\(stats.items?.count ?? 0)",
                    icon: "book.closed"
                )
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(NimbusTheme.Colors.accentPink)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(NimbusTheme.Colors.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(NimbusTheme.Colors.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Top Books

    private func topBooksSection(_ stats: ListeningStatsResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MOST LISTENED")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(NimbusTheme.Colors.textSecondary)
                .tracking(1.2)

            let sortedItems = (stats.items?.values ?? [:].values)
                .sorted { $0.timeListening > $1.timeListening }

            ForEach(Array(sortedItems.prefix(10).enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(NimbusTheme.Colors.accentPink)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.mediaMetadata?.title ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(NimbusTheme.Colors.textPrimary)
                            .lineLimit(1)

                        Text(item.mediaMetadata?.authors?.first?.name ?? "")
                            .font(.caption)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                    }

                    Spacer()

                    Text(formatHours(item.timeListening))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(NimbusTheme.Colors.textSecondary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Load

    private func loadStats() async {
        for server in servers where server.isActive {
            guard let client = serverService.client(for: server.id) else { continue }
            do {
                stats = try await client.getListeningStats()
                isLoading = false
                return
            } catch {
                continue
            }
        }
        isLoading = false
        errorMessage = "No server available"
    }

    // MARK: - Format

    private func formatHours(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
