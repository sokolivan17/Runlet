import XCTest
import RunnerEngine
import RunnerPersistence
@testable import RunnerFeatures

@MainActor
final class CollectionsViewModelTests: XCTestCase {
    func testImportAddsCollection() async throws {
        let viewModel = CollectionsViewModel(repository: try Fixtures.repository())
        await viewModel.importFile(Fixtures.collectionJSON())
        XCTAssertEqual(viewModel.items.map(\.name), ["Demo"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testImportInvalidFileShowsFriendlyMessage() async throws {
        let viewModel = CollectionsViewModel(repository: try Fixtures.repository())
        await viewModel.importFile(Data("nope".utf8))
        XCTAssertEqual(viewModel.errorMessage, "The file is not a valid Postman collection.")
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testDeleteRemovesItem() async throws {
        let viewModel = CollectionsViewModel(repository: try Fixtures.repository())
        await viewModel.importFile(Fixtures.collectionJSON())
        await viewModel.delete(viewModel.items[0])
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testSelectAndNavigationAreForwardedToCoordinator() async throws {
        let spy = SpyCoordinator()
        let viewModel = CollectionsViewModel(repository: try Fixtures.repository(), coordinator: spy)
        await viewModel.importFile(Fixtures.collectionJSON())
        viewModel.select(viewModel.items[0])
        viewModel.openEnvironments()
        viewModel.openHistory()
        XCTAssertEqual(spy.openedRunner?.name, "Demo")
        XCTAssertTrue(spy.environmentsShown)
        XCTAssertTrue(spy.historyShown)
    }
}

@MainActor
final class RunnerViewModelTests: XCTestCase {
    private func makeViewModel(repository: LiveRepository, json: Data = Fixtures.collectionJSON(),
                               coordinator: SpyCoordinator? = nil,
                               transport: MockTransport) async throws -> RunnerViewModel {
        let record = try await repository.importCollection(json)
        return RunnerViewModel(collection: record, collections: repository, environments: repository,
                               history: repository, engine: RunEngine(transport: transport), coordinator: coordinator)
    }

    func testRunFinishesAndSavesToHistory() async throws {
        let repository = try Fixtures.repository()
        let spy = SpyCoordinator()
        let viewModel = try await makeViewModel(repository: repository, coordinator: spy,
                                                transport: MockTransport { _ in (Data("ok".utf8), 200) })
        await viewModel.start()

        guard case .finished(let summary) = viewModel.state else { return XCTFail("Not finished: \(viewModel.state)") }
        XCTAssertEqual(summary.passed, 2)
        XCTAssertEqual(viewModel.outcomes.count, 2)
        XCTAssertEqual(viewModel.progress, 1)
        let saved = try await repository.runs(limit: 10)
        XCTAssertEqual(saved.count, 1)

        viewModel.openLastRun()
        XCTAssertEqual(spy.shownRun?.id, saved.first?.id)
    }

    func testSelectedEnvironmentSuppliesVariables() async throws {
        let repository = try Fixtures.repository()
        let recorder = URLRecorder()
        let viewModel = try await makeViewModel(
            repository: repository, json: Fixtures.collectionJSON(url: "https://{{host}}/x"),
            transport: MockTransport { request in
                await recorder.add(request.url!.absoluteString)
                return (Data(), 200)
            })
        let environment = try await repository.saveEnvironment(id: nil, name: "Stg", variables: ["host": "stg.example.com"])
        await viewModel.prepare()
        viewModel.selectedEnvironmentID = environment.id
        await viewModel.start()
        let urls = await recorder.urls
        XCTAssertEqual(urls, ["https://stg.example.com/x", "https://stg.example.com/x"])
    }

    func testIterationsAreClamped() async throws {
        let viewModel = try await makeViewModel(repository: try Fixtures.repository(),
                                                transport: MockTransport { _ in (Data(), 200) })
        viewModel.iterations = 500
        XCTAssertEqual(viewModel.plannedRequests, 2 * RunnerViewModel.maxIterations)
        viewModel.iterations = -3
        XCTAssertEqual(viewModel.plannedRequests, 2)
    }

    func testStopOnFailureEndsRunEarly() async throws {
        let viewModel = try await makeViewModel(repository: try Fixtures.repository(),
                                                transport: MockTransport { _ in (Data(), 500) })
        viewModel.stopOnFailure = true
        await viewModel.start()
        guard case .finished(let summary) = viewModel.state else { return XCTFail("Not finished") }
        XCTAssertTrue(summary.stoppedEarly)
        XCTAssertEqual(viewModel.outcomes.count, 1)
    }

    func testMissingCollectionSetsErrorAndStaysIdle() async throws {
        let repository = try Fixtures.repository()
        let record = try await repository.importCollection(Fixtures.collectionJSON())
        try await repository.deleteCollection(id: record.id)
        let viewModel = RunnerViewModel(collection: record, collections: repository, environments: repository,
                                        history: repository, engine: RunEngine(transport: MockTransport { _ in (Data(), 200) }))
        await viewModel.start()
        XCTAssertEqual(viewModel.errorMessage, "Item not found.")
        XCTAssertEqual(viewModel.state, .idle)
    }
}

@MainActor
final class HistoryViewModelTests: XCTestCase {
    private func seed(_ repository: LiveRepository, passed: Int, failed: Int) async throws -> RunRecord {
        let outcomes = (0..<(passed + failed)).map { index in
            RequestOutcome(iteration: 1, requestID: "\(index)", name: "R\(index)", method: "GET",
                           statusCode: index < passed ? 200 : 500, duration: 0.2, responseSize: 1, errorDescription: nil)
        }
        let summary = RunSummary(total: passed + failed, passed: passed, failed: failed, stoppedEarly: false, duration: 1)
        return try await repository.saveRun(collectionID: nil, collectionName: "Demo", startedAt: Date(),
                                            summary: summary, outcomes: outcomes)
    }

    func testLoadDeleteClearAndSelect() async throws {
        let repository = try Fixtures.repository()
        let spy = SpyCoordinator()
        _ = try await seed(repository, passed: 1, failed: 0)
        _ = try await seed(repository, passed: 2, failed: 0)
        let viewModel = HistoryViewModel(repository: repository, coordinator: spy)

        await viewModel.load()
        XCTAssertEqual(viewModel.items.count, 2)
        viewModel.select(viewModel.items[0])
        XCTAssertEqual(spy.shownRun?.id, viewModel.items[0].id)

        await viewModel.delete(viewModel.items[0])
        XCTAssertEqual(viewModel.items.count, 1)
        await viewModel.clear()
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testRunDetailFilterAndStatistics() async throws {
        let record = try await seed(try Fixtures.repository(), passed: 3, failed: 1)
        let viewModel = RunDetailViewModel(run: record)
        XCTAssertEqual(viewModel.visibleOutcomes.count, 4)
        viewModel.showFailedOnly = true
        XCTAssertEqual(viewModel.visibleOutcomes.count, 1)
        XCTAssertEqual(viewModel.passRate, 0.75, accuracy: 0.0001)
        XCTAssertEqual(viewModel.averageDuration, 0.2, accuracy: 0.0001)
    }
}

@MainActor
final class EnvironmentsViewModelTests: XCTestCase {
    func testParseIgnoresCommentsBlankLinesAndInvalidLines() {
        let text = """
        # staging
        host = stg.example.com

        token=a=b
        =novalue
        justtext
        """
        XCTAssertEqual(EnvironmentsViewModel.parse(text), ["host": "stg.example.com", "token": "a=b"])
    }

    func testFormatIsSortedAndRoundTrips() {
        let variables = ["b": "2", "a": "1"]
        XCTAssertEqual(EnvironmentsViewModel.format(variables), "a=1\nb=2")
        XCTAssertEqual(EnvironmentsViewModel.parse(EnvironmentsViewModel.format(variables)), variables)
    }

    func testSaveRequiresName() async throws {
        let viewModel = EnvironmentsViewModel(repository: try Fixtures.repository())
        let saved = await viewModel.save(name: "  ", variablesText: "a=1")
        XCTAssertFalse(saved)
        XCTAssertEqual(viewModel.errorMessage, "Name is required.")
    }

    func testSaveUpdatesAndDeletes() async throws {
        let viewModel = EnvironmentsViewModel(repository: try Fixtures.repository())
        await viewModel.save(name: "Stg", variablesText: "host=stg")
        XCTAssertEqual(viewModel.items.first?.variables, ["host": "stg"])
        let id = viewModel.items[0].id
        await viewModel.save(id: id, name: "Stg", variablesText: "host=stg2")
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.variables, ["host": "stg2"])
        await viewModel.delete(viewModel.items[0])
        XCTAssertTrue(viewModel.items.isEmpty)
    }
}
