import Foundation
import RunnerCore
import RunnerEngine
import RunnerPersistence

// View models depend on these small protocols, not on SwiftData or the store actor.

public protocol CollectionsRepository: Sendable {
    func collections() async throws -> [CollectionRecord]
    func importCollection(_ data: Data) async throws -> CollectionRecord
    func loadCollection(id: UUID) async throws -> RequestCollection
    func deleteCollection(id: UUID) async throws
}

public protocol EnvironmentsRepository: Sendable {
    func environments() async throws -> [EnvironmentRecord]
    func saveEnvironment(id: UUID?, name: String, variables: [String: String]) async throws -> EnvironmentRecord
    func deleteEnvironment(id: UUID) async throws
}

public protocol HistoryRepository: Sendable {
    func runs(limit: Int) async throws -> [RunRecord]
    func saveRun(collectionID: UUID?, collectionName: String, startedAt: Date,
                 summary: RunSummary, outcomes: [RequestOutcome]) async throws -> RunRecord
    func deleteRun(id: UUID) async throws
    func clearHistory() async throws
}

/// Production implementation: forwards everything to `RunnerStore`.
public struct LiveRepository: CollectionsRepository, EnvironmentsRepository, HistoryRepository {
    private let store: RunnerStore

    public init(store: RunnerStore) { self.store = store }

    public func collections() async throws -> [CollectionRecord] { try await store.collections() }
    public func importCollection(_ data: Data) async throws -> CollectionRecord { try await store.importCollection(data) }
    public func loadCollection(id: UUID) async throws -> RequestCollection { try await store.loadCollection(id: id) }
    public func deleteCollection(id: UUID) async throws { try await store.deleteCollection(id: id) }

    public func environments() async throws -> [EnvironmentRecord] { try await store.environments() }
    public func saveEnvironment(id: UUID?, name: String, variables: [String: String]) async throws -> EnvironmentRecord {
        try await store.saveEnvironment(id: id, name: name, variables: variables)
    }
    public func deleteEnvironment(id: UUID) async throws { try await store.deleteEnvironment(id: id) }

    public func runs(limit: Int) async throws -> [RunRecord] { try await store.runs(limit: limit) }
    public func saveRun(collectionID: UUID?, collectionName: String, startedAt: Date,
                        summary: RunSummary, outcomes: [RequestOutcome]) async throws -> RunRecord {
        try await store.saveRun(collectionID: collectionID, collectionName: collectionName,
                                startedAt: startedAt, summary: summary, outcomes: outcomes)
    }
    public func deleteRun(id: UUID) async throws { try await store.deleteRun(id: id) }
    public func clearHistory() async throws { try await store.clearHistory() }
}
