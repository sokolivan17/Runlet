import Foundation
import RunnerEngine
import RunnerPersistence
@testable import RunnerFeatures

struct MockTransport: HTTPTransport {
    let handler: @Sendable (URLRequest) async throws -> (Data, Int)

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, status) = try await handler(request)
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

actor URLRecorder {
    private(set) var urls: [String] = []
    func add(_ url: String) { urls.append(url) }
}

@MainActor
final class SpyCoordinator: CollectionsCoordinating, RunnerCoordinating, HistoryCoordinating {
    var openedRunner: CollectionRecord?
    var shownRun: RunRecord?
    var environmentsShown = false
    var historyShown = false

    func showRunner(for collection: CollectionRecord) { openedRunner = collection }
    func showEnvironments() { environmentsShown = true }
    func showHistory() { historyShown = true }
    func showRunDetail(_ run: RunRecord) { shownRun = run }
}

enum Fixtures {
    static func collectionJSON(url: String = "https://example.com/ping") -> Data {
        Data("""
        {"info": {"name": "Demo", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"},
         "item": [{"name": "A", "request": "\(url)"}, {"name": "B", "request": "\(url)"}]}
        """.utf8)
    }

    static func repository() throws -> LiveRepository {
        LiveRepository(store: try RunnerStore.make(inMemory: true))
    }
}
