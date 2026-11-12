import Foundation
import SwiftData

// Internal SwiftData models. The rest of the app only sees the Sendable records in Records.swift.

@Model
final class StoredCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var importedAt: Date
    var requestCount: Int
    /// The original Postman JSON. Re-parsed on load, so the tree never has to be mapped to relationships.
    @Attribute(.externalStorage) var rawJSON: Data

    init(id: UUID = UUID(), name: String, importedAt: Date, requestCount: Int, rawJSON: Data) {
        self.id = id
        self.name = name
        self.importedAt = importedAt
        self.requestCount = requestCount
        self.rawJSON = rawJSON
    }
}

@Model
final class StoredEnvironment {
    @Attribute(.unique) var id: UUID
    var name: String
    var variables: [String: String]

    init(id: UUID = UUID(), name: String, variables: [String: String]) {
        self.id = id
        self.name = name
        self.variables = variables
    }
}

@Model
final class StoredRun {
    @Attribute(.unique) var id: UUID
    var collectionID: UUID?
    var collectionName: String
    var startedAt: Date
    var total: Int
    var passed: Int
    var failed: Int
    var stoppedEarly: Bool
    var duration: Double
    @Relationship(deleteRule: .cascade, inverse: \StoredResult.run) var results: [StoredResult] = []

    init(id: UUID = UUID(), collectionID: UUID?, collectionName: String, startedAt: Date,
         total: Int, passed: Int, failed: Int, stoppedEarly: Bool, duration: Double) {
        self.id = id
        self.collectionID = collectionID
        self.collectionName = collectionName
        self.startedAt = startedAt
        self.total = total
        self.passed = passed
        self.failed = failed
        self.stoppedEarly = stoppedEarly
        self.duration = duration
    }
}

@Model
final class StoredResult {
    var order: Int
    var iteration: Int
    var requestID: String
    var name: String
    var method: String
    var statusCode: Int?
    var duration: Double
    var responseSize: Int
    var errorDescription: String?
    var run: StoredRun?

    init(order: Int, iteration: Int, requestID: String, name: String, method: String,
         statusCode: Int?, duration: Double, responseSize: Int, errorDescription: String?) {
        self.order = order
        self.iteration = iteration
        self.requestID = requestID
        self.name = name
        self.method = method
        self.statusCode = statusCode
        self.duration = duration
        self.responseSize = responseSize
        self.errorDescription = errorDescription
    }
}
