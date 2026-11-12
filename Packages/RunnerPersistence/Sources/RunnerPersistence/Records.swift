import Foundation
import RunnerEngine

public struct CollectionRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let importedAt: Date
    public let requestCount: Int
}

public struct EnvironmentRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let variables: [String: String]
}

public struct RunRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let collectionID: UUID?
    public let collectionName: String
    public let startedAt: Date
    public let summary: RunSummary
    public let outcomes: [RequestOutcome]
}

extension StoredCollection {
    var record: CollectionRecord {
        CollectionRecord(id: id, name: name, importedAt: importedAt, requestCount: requestCount)
    }
}

extension StoredEnvironment {
    var record: EnvironmentRecord {
        EnvironmentRecord(id: id, name: name, variables: variables)
    }
}

extension StoredRun {
    var record: RunRecord {
        RunRecord(
            id: id, collectionID: collectionID, collectionName: collectionName, startedAt: startedAt,
            summary: RunSummary(total: total, passed: passed, failed: failed, stoppedEarly: stoppedEarly, duration: duration),
            outcomes: results.sorted { $0.order < $1.order }.map {
                RequestOutcome(iteration: $0.iteration, requestID: $0.requestID, name: $0.name, method: $0.method,
                               statusCode: $0.statusCode, duration: $0.duration,
                               responseSize: $0.responseSize, errorDescription: $0.errorDescription)
            })
    }
}
