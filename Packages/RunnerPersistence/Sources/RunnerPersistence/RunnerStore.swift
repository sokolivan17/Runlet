import Foundation
import SwiftData
import RunnerCore
import RunnerEngine

public enum StoreError: Error, Equatable {
    case notFound
}

/// Single entry point to persistence. All SwiftData work happens on this actor's own context;
/// callers exchange only Sendable value types, so view models never touch `@Model` objects.
@ModelActor
public actor RunnerStore {
    public static func make(inMemory: Bool = false) throws -> RunnerStore {
        let schema = Schema([StoredCollection.self, StoredEnvironment.self, StoredRun.self, StoredResult.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return RunnerStore(modelContainer: try ModelContainer(for: schema, configurations: configuration))
    }

    // MARK: - Collections

    /// Validates the JSON with the parser first, so broken files are never stored.
    public func importCollection(_ data: Data, importedAt: Date = Date()) throws -> CollectionRecord {
        let parsed = try PostmanCollectionParser().parse(data)
        let stored = StoredCollection(name: parsed.name, importedAt: importedAt,
                                      requestCount: parsed.allRequests.count, rawJSON: data)
        modelContext.insert(stored)
        try modelContext.save()
        return stored.record
    }

    public func collections() throws -> [CollectionRecord] {
        let descriptor = FetchDescriptor<StoredCollection>(sortBy: [SortDescriptor(\.importedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.record)
    }

    public func loadCollection(id: UUID) throws -> RequestCollection {
        guard let stored = try fetchCollection(id) else { throw StoreError.notFound }
        return try PostmanCollectionParser().parse(stored.rawJSON)
    }

    public func deleteCollection(id: UUID) throws {
        guard let stored = try fetchCollection(id) else { throw StoreError.notFound }
        modelContext.delete(stored)
        try modelContext.save()
    }

    // MARK: - Environments

    /// Creates a new environment, or updates the one with the given id.
    public func saveEnvironment(id: UUID? = nil, name: String, variables: [String: String]) throws -> EnvironmentRecord {
        if let id, let existing = try fetchEnvironment(id) {
            existing.name = name
            existing.variables = variables
            try modelContext.save()
            return existing.record
        }
        let stored = StoredEnvironment(name: name, variables: variables)
        modelContext.insert(stored)
        try modelContext.save()
        return stored.record
    }

    public func environments() throws -> [EnvironmentRecord] {
        let descriptor = FetchDescriptor<StoredEnvironment>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor).map(\.record)
    }

    public func deleteEnvironment(id: UUID) throws {
        guard let stored = try fetchEnvironment(id) else { throw StoreError.notFound }
        modelContext.delete(stored)
        try modelContext.save()
    }

    // MARK: - Run history

    public func saveRun(collectionID: UUID?, collectionName: String, startedAt: Date,
                        summary: RunSummary, outcomes: [RequestOutcome]) throws -> RunRecord {
        let run = StoredRun(collectionID: collectionID, collectionName: collectionName, startedAt: startedAt,
                            total: summary.total, passed: summary.passed, failed: summary.failed,
                            stoppedEarly: summary.stoppedEarly, duration: summary.duration)
        modelContext.insert(run)
        for (index, outcome) in outcomes.enumerated() {
            let result = StoredResult(order: index, iteration: outcome.iteration, requestID: outcome.requestID,
                                      name: outcome.name, method: outcome.method, statusCode: outcome.statusCode,
                                      duration: outcome.duration, responseSize: outcome.responseSize,
                                      errorDescription: outcome.errorDescription)
            modelContext.insert(result)
            result.run = run
        }
        try modelContext.save()
        return run.record
    }

    public func runs(limit: Int = 50) throws -> [RunRecord] {
        var descriptor = FetchDescriptor<StoredRun>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map(\.record)
    }

    public func deleteRun(id: UUID) throws {
        var descriptor = FetchDescriptor<StoredRun>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let run = try modelContext.fetch(descriptor).first else { throw StoreError.notFound }
        modelContext.delete(run)
        try modelContext.save()
    }

    public func clearHistory() throws {
        // Deleted one by one so the cascade rule removes each run's results.
        for run in try modelContext.fetch(FetchDescriptor<StoredRun>()) {
            modelContext.delete(run)
        }
        try modelContext.save()
    }

    // MARK: - Lookups

    private func fetchCollection(_ id: UUID) throws -> StoredCollection? {
        var descriptor = FetchDescriptor<StoredCollection>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchEnvironment(_ id: UUID) throws -> StoredEnvironment? {
        var descriptor = FetchDescriptor<StoredEnvironment>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
