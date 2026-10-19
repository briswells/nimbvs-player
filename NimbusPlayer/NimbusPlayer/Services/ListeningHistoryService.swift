import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.nimbusplayer.app", category: "ListeningHistoryService")

/// What a `ListeningHistoryView` should show: either all books or a single book.
enum SessionFilter {
    case all
    case book(CachedBook)
}

/// Flattened view-model for a history row.
struct SessionRow: Identifiable, Equatable {
    let id: String
    let serverId: UUID
    let serverName: String
    let libraryItemId: String
    let bookTitle: String
    let bookAuthor: String
    let startedAt: Date
    let startTime: TimeInterval
    let endTime: TimeInterval
    let timeListened: TimeInterval
    let duration: TimeInterval?
}

/// Stateless helper that fans out `getListeningSessions` across servers and merges the results.
struct ListeningHistoryService {

    struct FetchResult: Equatable {
        let rows: [SessionRow]
        let hasMore: Bool
        let failedServers: [String]
    }

    // MARK: - Pure merge (tested)

    /// Merges pages from multiple servers into a single sorted, deduped, capped page.
    ///
    /// - Parameters:
    ///   - pagesByServer: One tuple per contributing server, carrying the UUID, display name,
    ///     and the page payload returned by that server.
    ///   - currentSessionId: Session id of the currently active playback session, or nil. The
    ///     active session is filtered out so it doesn't clutter history.
    ///   - itemsPerPage: Cap for the returned row count.
    static func merge(
        pagesByServer: [(serverId: UUID, serverName: String, page: ListeningSessionsPage)],
        currentSessionId: String?,
        itemsPerPage: Int
    ) -> FetchResult {
        var rows: [SessionRow] = []
        var seenIds = Set<String>()
        var hasMore = false

        for entry in pagesByServer {
            if entry.page.page + 1 < entry.page.numPages {
                hasMore = true
            }
            for session in entry.page.sessions {
                guard session.id != currentSessionId else { continue }
                guard !seenIds.contains(session.id) else { continue }
                guard let itemId = session.libraryItemId else { continue }
                seenIds.insert(session.id)
                rows.append(SessionRow(
                    id: session.id,
                    serverId: entry.serverId,
                    serverName: entry.serverName,
                    libraryItemId: itemId,
                    bookTitle: session.displayTitle ?? session.mediaMetadata?.title ?? "Unknown",
                    bookAuthor: session.displayAuthor ?? session.mediaMetadata?.authors?.first?.name ?? "",
                    startedAt: Date(timeIntervalSince1970: session.startedAt / 1000),
                    startTime: session.startTime,
                    endTime: session.currentTime,
                    timeListened: session.timeListening,
                    duration: session.duration
                ))
            }
        }

        rows.sort { $0.startedAt > $1.startedAt }
        if rows.count > itemsPerPage {
            rows = Array(rows.prefix(itemsPerPage))
        }
        return FetchResult(rows: rows, hasMore: hasMore, failedServers: [])
    }

    // MARK: - Fetch

    /// Fetches a single logical page of sessions by fanning out to the given servers.
    ///
    /// For `.book(book)`, only servers that map the book are queried, each filtered to the
    /// mapping's `libraryItemId`. For `.all`, every active server is queried unfiltered.
    func fetchPage(
        page: Int,
        itemsPerPage: Int = 25,
        filter: SessionFilter,
        currentSessionId: String?,
        servers: [Server],
        serverService: ServerService
    ) async -> FetchResult {
        let targets = resolveTargets(filter: filter, servers: servers, serverService: serverService)

        var pagesByServer: [(serverId: UUID, serverName: String, page: ListeningSessionsPage)] = []
        var failedServers: [String] = []

        await withTaskGroup(of: (UUID, String, Result<ListeningSessionsPage, Error>).self) { group in
            for target in targets {
                group.addTask {
                    do {
                        let fetchedPage = try await target.client.getListeningSessions(
                            itemId: target.libraryItemId,
                            page: page,
                            itemsPerPage: itemsPerPage
                        )
                        return (target.serverId, target.serverName, .success(fetchedPage))
                    } catch {
                        return (target.serverId, target.serverName, .failure(error))
                    }
                }
            }
            for await (serverId, serverName, result) in group {
                switch result {
                case .success(let page):
                    logger.info("fetched \(page.sessions.count) sessions from \(serverName) (page \(page.page)/\(page.numPages))")
                    pagesByServer.append((serverId, serverName, page))
                case .failure(let error):
                    logger.error("fetch failed for \(serverName): \(String(describing: error))")
                    failedServers.append(serverName)
                }
            }
        }

        let merged = Self.merge(
            pagesByServer: pagesByServer,
            currentSessionId: currentSessionId,
            itemsPerPage: itemsPerPage
        )
        return FetchResult(
            rows: merged.rows,
            hasMore: merged.hasMore,
            failedServers: failedServers
        )
    }

    // MARK: - Private

    private struct Target {
        let serverId: UUID
        let serverName: String
        let client: APIClient
        let libraryItemId: String?
    }

    private func resolveTargets(
        filter: SessionFilter,
        servers: [Server],
        serverService: ServerService
    ) -> [Target] {
        switch filter {
        case .all:
            return servers.compactMap { server in
                guard server.isActive, let client = serverService.client(for: server.id) else { return nil }
                return Target(
                    serverId: server.id,
                    serverName: server.displayName,
                    client: client,
                    libraryItemId: nil
                )
            }
        case .book(let book):
            return book.serverMappings.compactMap { mapping in
                guard let server = mapping.server,
                      server.isActive,
                      let client = serverService.client(for: server.id) else { return nil }
                return Target(
                    serverId: server.id,
                    serverName: server.displayName,
                    client: client,
                    libraryItemId: mapping.libraryItemId
                )
            }
        }
    }
}
