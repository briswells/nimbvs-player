import Foundation
import SwiftData

// MARK: - SyncQueueService

/// Manages a durable queue of server-bound operations that are retried until successful.
@Observable
final class SyncQueueService {

    // MARK: - Enqueue

    /// Enqueues an action and attempts to flush it immediately.
    /// If the immediate flush fails, the action stays queued for the next refresh.
    func enqueue(
        action: SyncActionType,
        payload: any Codable,
        serverId: UUID,
        modelContext: ModelContext,
        serverService: ServerService
    ) {
        guard let data = try? JSONEncoder().encode(AnyEncodableWrapper(payload)) else { return }
        let pending = PendingSyncAction(actionType: action.rawValue, payload: data, serverId: serverId)
        modelContext.insert(pending)
        try? modelContext.save()

        // Try to flush immediately in the background
        let actionId = pending.id
        Task {
            await self.flushSingle(actionId: actionId, modelContext: modelContext, serverService: serverService)
        }
    }

    // MARK: - Flush Queue

    /// Processes all pending actions in creation order. Successful actions are deleted;
    /// failed actions remain for the next flush cycle.
    @MainActor
    func flushQueue(modelContext: ModelContext, serverService: ServerService) async {
        let descriptor = FetchDescriptor<PendingSyncAction>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let pending = try? modelContext.fetch(descriptor), !pending.isEmpty else { return }

        for action in pending {
            let success = await execute(action: action, serverService: serverService)
            if success {
                modelContext.delete(action)
            }
        }

        try? modelContext.save()
    }

    // MARK: - Private

    @MainActor
    private func flushSingle(actionId: UUID, modelContext: ModelContext, serverService: ServerService) async {
        let descriptor = FetchDescriptor<PendingSyncAction>(
            predicate: #Predicate<PendingSyncAction> { $0.id == actionId }
        )
        guard let action = try? modelContext.fetch(descriptor).first else { return }

        let success = await execute(action: action, serverService: serverService)
        if success {
            modelContext.delete(action)
            try? modelContext.save()
        }
    }

    private func execute(action: PendingSyncAction, serverService: ServerService) async -> Bool {
        guard let client = serverService.client(for: action.serverId) else { return false }

        guard let type = SyncActionType(rawValue: action.actionType) else { return true } // unknown type, discard

        do {
            switch type {
            case .bookmarkCreate:
                let p = try JSONDecoder().decode(BookmarkCreatePayload.self, from: action.payload)
                _ = try await client.createBookmark(libraryItemId: p.libraryItemId, time: p.time, title: p.title)

            case .bookmarkDelete:
                let p = try JSONDecoder().decode(BookmarkDeletePayload.self, from: action.payload)
                try await client.deleteBookmark(libraryItemId: p.libraryItemId, time: p.time)

            case .seriesHide:
                let p = try JSONDecoder().decode(SeriesHidePayload.self, from: action.payload)
                try await client.hideSeriesFromContinueListening(seriesId: p.seriesId)

            case .markComplete:
                let p = try JSONDecoder().decode(MarkCompletePayload.self, from: action.payload)
                let request = ProgressUpdateRequest(
                    progress: p.progress,
                    currentTime: p.currentTime,
                    duration: p.duration,
                    isFinished: true
                )
                try await client.updateProgress(libraryItemId: p.libraryItemId, progress: request)
            }
            return true
        } catch {
            return false
        }
    }
}

// MARK: - AnyEncodableWrapper

/// Type-erasing wrapper for encoding any Codable value to Data.
private struct AnyEncodableWrapper: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        _encode = { encoder in try value.encode(to: encoder) }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
