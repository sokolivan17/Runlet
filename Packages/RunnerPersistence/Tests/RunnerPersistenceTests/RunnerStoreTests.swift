import XCTest
import RunnerCore
import RunnerEngine
@testable import RunnerPersistence

final class RunnerStoreTests: XCTestCase {
    private let sampleJSON = Data(#"""
    {"info": {"name": "Demo", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"},
     "item": [{"name": "Ping", "request": "https://example.com/ping"},
              {"name": "Pong", "request": "https://example.com/pong"}]}
    """#.utf8)

    private func makeStore() throws -> RunnerStore {
        try RunnerStore.make(inMemory: true)
    }

    private func outcome(_ index: Int, status: Int? = 200) -> RequestOutcome {
        RequestOutcome(iteration: 1, requestID: "\(index)", name: "R\(index)", method: "GET", statusCode: status,
                       duration: 0.1, responseSize: 10, errorDescription: nil)
    }

    private func summary(total: Int) -> RunSummary {
        RunSummary(total: total, passed: total, failed: 0, stoppedEarly: false, duration: 1.5)
    }

    // MARK: Collections

    func testImportStoresNameAndRequestCount() async throws {
        let store = try makeStore()
        let record = try await store.importCollection(sampleJSON)
        XCTAssertEqual(record.name, "Demo")
        XCTAssertEqual(record.requestCount, 2)
    }

    func testImportRejectsInvalidJSONAndStoresNothing() async throws {
        let store = try makeStore()
        do {
            _ = try await store.importCollection(Data("nope".utf8))
            XCTFail("Expected an error")
        } catch {
            XCTAssertTrue(error is CollectionParseError)
        }
        let all = try await store.collections()
        XCTAssertTrue(all.isEmpty)
    }

    func testCollectionsAreSortedNewestFirst() async throws {
        let store = try makeStore()
        _ = try await store.importCollection(sampleJSON, importedAt: Date(timeIntervalSince1970: 100))
        let newer = try await store.importCollection(sampleJSON, importedAt: Date(timeIntervalSince1970: 200))
        let all = try await store.collections()
        XCTAssertEqual(all.first?.id, newer.id)
    }

    func testLoadCollectionRoundTrips() async throws {
        let store = try makeStore()
        let record = try await store.importCollection(sampleJSON)
        let loaded = try await store.loadCollection(id: record.id)
        XCTAssertEqual(loaded.allRequests.map(\.name), ["Ping", "Pong"])
    }

    func testDeleteCollection() async throws {
        let store = try makeStore()
        let record = try await store.importCollection(sampleJSON)
        try await store.deleteCollection(id: record.id)
        do {
            _ = try await store.loadCollection(id: record.id)
            XCTFail("Expected notFound")
        } catch {
            XCTAssertEqual(error as? StoreError, .notFound)
        }
    }

    // MARK: Environments

    func testSaveEnvironmentCreatesThenUpdatesSameRecord() async throws {
        let store = try makeStore()
        let created = try await store.saveEnvironment(name: "Staging", variables: ["host": "stg"])
        let updated = try await store.saveEnvironment(id: created.id, name: "Staging 2", variables: ["host": "stg2"])
        let all = try await store.environments()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(updated.id, created.id)
        XCTAssertEqual(all.first?.name, "Staging 2")
        XCTAssertEqual(all.first?.variables, ["host": "stg2"])
    }

    func testDeleteEnvironment() async throws {
        let store = try makeStore()
        let created = try await store.saveEnvironment(name: "Prod", variables: [:])
        try await store.deleteEnvironment(id: created.id)
        let all = try await store.environments()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: History

    func testSaveRunKeepsSummaryAndOutcomeOrder() async throws {
        let store = try makeStore()
        let outcomes = [outcome(0), outcome(1, status: 500), outcome(2)]
        let record = try await store.saveRun(collectionID: nil, collectionName: "Demo", startedAt: Date(),
                                             summary: summary(total: 3), outcomes: outcomes)
        XCTAssertEqual(record.summary, summary(total: 3))
        XCTAssertEqual(record.outcomes, outcomes)
    }

    func testRunsAreNewestFirstAndRespectLimit() async throws {
        let store = try makeStore()
        for seconds in [100.0, 300.0, 200.0] {
            _ = try await store.saveRun(collectionID: nil, collectionName: "C", startedAt: Date(timeIntervalSince1970: seconds),
                                        summary: summary(total: 0), outcomes: [])
        }
        let latest = try await store.runs(limit: 2)
        XCTAssertEqual(latest.map { $0.startedAt.timeIntervalSince1970 }, [300, 200])
    }

    func testDeleteRunAndClearHistory() async throws {
        let store = try makeStore()
        let first = try await store.saveRun(collectionID: nil, collectionName: "A", startedAt: Date(),
                                            summary: summary(total: 1), outcomes: [outcome(0)])
        _ = try await store.saveRun(collectionID: nil, collectionName: "B", startedAt: Date(),
                                    summary: summary(total: 1), outcomes: [outcome(0)])
        try await store.deleteRun(id: first.id)
        let afterDelete = try await store.runs()
        XCTAssertEqual(afterDelete.count, 1)
        try await store.clearHistory()
        let afterClear = try await store.runs()
        XCTAssertTrue(afterClear.isEmpty)
    }
}
