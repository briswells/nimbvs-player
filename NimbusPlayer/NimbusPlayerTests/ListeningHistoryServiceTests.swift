import Testing
import Foundation
@testable import NimbusPlayer

@Suite("ListeningHistoryService Tests")
struct ListeningHistoryServiceTests {

    private let serverA = UUID()
    private let serverB = UUID()

    private func session(
        id: String,
        startedAtMs: Double,
        currentTime: Double = 100,
        startTime: Double = 0,
        timeListening: Double = 60,
        duration: Double? = 3600,
        itemId: String = "item-1",
        title: String = "Book One",
        author: String = "Author A"
    ) -> ListeningSessionResponse {
        ListeningSessionResponse(
            id: id,
            libraryItemId: itemId,
            displayTitle: title,
            displayAuthor: author,
            mediaMetadata: nil,
            playMethod: 0,
            startedAt: startedAtMs,
            updatedAt: startedAtMs + 60_000,
            startTime: startTime,
            currentTime: currentTime,
            duration: duration,
            timeListening: timeListening,
            deviceInfo: nil
        )
    }

    private func page(_ sessions: [ListeningSessionResponse], page: Int = 0, total: Int? = nil) -> ListeningSessionsPage {
        ListeningSessionsPage(
            total: total ?? sessions.count,
            numPages: 1,
            page: page,
            itemsPerPage: 25,
            sessions: sessions
        )
    }

    @Test func mergeSortsByStartedAtDescending() {
        let pages = [
            (serverId: serverA, serverName: "A", page: page([
                session(id: "s1", startedAtMs: 1_000),
                session(id: "s2", startedAtMs: 3_000)
            ]))
        ]
        let result = ListeningHistoryService.merge(
            pagesByServer: pages,
            currentSessionId: nil,
            itemsPerPage: 25
        )
        #expect(result.rows.map(\.id) == ["s2", "s1"])
    }

    @Test func mergeDedupesBySessionId() {
        let pages = [
            (serverId: serverA, serverName: "A", page: page([
                session(id: "s1", startedAtMs: 1_000)
            ])),
            (serverId: serverB, serverName: "B", page: page([
                session(id: "s1", startedAtMs: 1_000) // duplicate id
            ]))
        ]
        let result = ListeningHistoryService.merge(
            pagesByServer: pages,
            currentSessionId: nil,
            itemsPerPage: 25
        )
        #expect(result.rows.count == 1)
    }

    @Test func mergeFiltersActiveSession() {
        let pages = [
            (serverId: serverA, serverName: "A", page: page([
                session(id: "current-session", startedAtMs: 3_000),
                session(id: "older", startedAtMs: 1_000)
            ]))
        ]
        let result = ListeningHistoryService.merge(
            pagesByServer: pages,
            currentSessionId: "current-session",
            itemsPerPage: 25
        )
        #expect(result.rows.map(\.id) == ["older"])
    }

    @Test func mergeCapsAtItemsPerPage() {
        var sessions: [ListeningSessionResponse] = []
        for i in 0..<40 {
            sessions.append(session(id: "s\(i)", startedAtMs: Double(i) * 1000))
        }
        let result = ListeningHistoryService.merge(
            pagesByServer: [(serverId: serverA, serverName: "A", page: page(sessions))],
            currentSessionId: nil,
            itemsPerPage: 25
        )
        #expect(result.rows.count == 25)
        // Top row should be the newest (s39)
        #expect(result.rows.first?.id == "s39")
    }

    @Test func mergeReportsHasMoreWhenAnyServerHasMorePages() {
        let pageA = ListeningSessionsPage(total: 50, numPages: 2, page: 0, itemsPerPage: 25,
                                          sessions: [session(id: "a", startedAtMs: 1_000)])
        let pageB = ListeningSessionsPage(total: 1, numPages: 1, page: 0, itemsPerPage: 25,
                                          sessions: [session(id: "b", startedAtMs: 2_000)])
        let result = ListeningHistoryService.merge(
            pagesByServer: [
                (serverId: serverA, serverName: "A", page: pageA),
                (serverId: serverB, serverName: "B", page: pageB)
            ],
            currentSessionId: nil,
            itemsPerPage: 25
        )
        #expect(result.hasMore == true)
    }

    @Test func mergeCarriesServerNameOntoRows() {
        let pages = [
            (serverId: serverA, serverName: "Home", page: page([
                session(id: "s1", startedAtMs: 1_000)
            ]))
        ]
        let result = ListeningHistoryService.merge(
            pagesByServer: pages,
            currentSessionId: nil,
            itemsPerPage: 25
        )
        #expect(result.rows.first?.serverName == "Home")
        #expect(result.rows.first?.serverId == serverA)
    }
}
