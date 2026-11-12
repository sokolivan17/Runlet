import XCTest
import RunnerCore
@testable import RunnerEngine

private struct MockTransport: HTTPTransport {
    let handler: @Sendable (URLRequest) async throws -> (Data, Int)

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, status) = try await handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}

private actor Recorder {
    private(set) var urls: [String] = []
    func add(_ url: String) { urls.append(url) }
}

final class RunEngineTests: XCTestCase {
    private func collection(_ names: [String]) -> RequestCollection {
        RequestCollection(name: "T", items: names.enumerated().map { index, name in
            .request(RequestDefinition(id: "\(index)", name: name, url: "https://example.com/\(name)"))
        })
    }

    private func collect(_ stream: AsyncStream<RunEvent>) async -> [RunEvent] {
        var events: [RunEvent] = []
        for await event in stream { events.append(event) }
        return events
    }

    private func outcomes(_ events: [RunEvent]) -> [RequestOutcome] {
        events.compactMap { if case .requestFinished(let outcome) = $0 { return outcome } else { return nil } }
    }

    private func summary(_ events: [RunEvent]) -> RunSummary? {
        events.compactMap { if case .completed(let summary) = $0 { return summary } else { return nil } }.first
    }

    func testRunsRequestsInOrder() async {
        let recorder = Recorder()
        let engine = RunEngine(transport: MockTransport { request in
            await recorder.add(request.url!.absoluteString)
            return (Data("ok".utf8), 200)
        })
        let events = await collect(engine.run(collection(["a", "b", "c"])))
        let urls = await recorder.urls
        XCTAssertEqual(urls, ["https://example.com/a", "https://example.com/b", "https://example.com/c"])
        XCTAssertEqual(summary(events)?.passed, 3)
        XCTAssertEqual(summary(events)?.stoppedEarly, false)
    }

    func testIterationsMultiplyRequests() async {
        let engine = RunEngine(transport: MockTransport { _ in (Data(), 200) })
        let events = await collect(engine.run(collection(["a", "b"]), configuration: RunConfiguration(iterations: 3)))
        XCTAssertEqual(outcomes(events).count, 6)
        XCTAssertEqual(outcomes(events).last?.iteration, 3)
    }

    func testStopOnFailureHaltsRun() async {
        let engine = RunEngine(transport: MockTransport { _ in (Data(), 500) })
        let events = await collect(engine.run(collection(["a", "b"]), configuration: RunConfiguration(stopOnFailure: true)))
        XCTAssertEqual(outcomes(events).count, 1)
        XCTAssertEqual(summary(events)?.failed, 1)
        XCTAssertEqual(summary(events)?.stoppedEarly, true)
    }

    func testNetworkErrorIsRecordedAsFailure() async {
        let engine = RunEngine(transport: MockTransport { _ in throw URLError(.notConnectedToInternet) })
        let events = await collect(engine.run(collection(["a"])))
        let outcome = outcomes(events).first
        XCTAssertNil(outcome?.statusCode)
        XCTAssertNotNil(outcome?.errorDescription)
        XCTAssertEqual(outcome?.isSuccess, false)
    }

    func testBuildErrorDoesNotReachTransport() async {
        let recorder = Recorder()
        let engine = RunEngine(transport: MockTransport { request in
            await recorder.add(request.url!.absoluteString)
            return (Data(), 200)
        })
        let broken = RequestCollection(name: "T", items: [
            .request(RequestDefinition(id: "0", name: "A", url: "https://{{missing}}/x"))
        ])
        let events = await collect(engine.run(broken))
        let urls = await recorder.urls
        XCTAssertTrue(urls.isEmpty)
        XCTAssertEqual(summary(events)?.failed, 1)
    }

    func testEnvironmentOverridesCollectionVariables() async {
        let recorder = Recorder()
        let engine = RunEngine(transport: MockTransport { request in
            await recorder.add(request.url!.absoluteString)
            return (Data(), 200)
        })
        let source = RequestCollection(
            name: "T",
            items: [.request(RequestDefinition(id: "0", name: "A", url: "https://{{host}}/x"))],
            variables: ["host": "collection.example.com"])
        _ = await collect(engine.run(source, configuration: RunConfiguration(environment: ["host": "env.example.com"])))
        let urls = await recorder.urls
        XCTAssertEqual(urls, ["https://env.example.com/x"])
    }

    func testStopEndsRunAfterCurrentRequest() async {
        let control = RunControl()
        let engine = RunEngine(transport: MockTransport { _ in
            await control.stop()
            return (Data(), 200)
        })
        let events = await collect(engine.run(collection(["a", "b", "c"]), control: control))
        XCTAssertEqual(outcomes(events).count, 1)
        XCTAssertEqual(summary(events)?.stoppedEarly, true)
    }

    func testPauseHoldsRunUntilResumed() async {
        let control = RunControl()
        await control.pause()
        let engine = RunEngine(transport: MockTransport { _ in (Data(), 200) })
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await control.resume()
        }
        let events = await collect(engine.run(collection(["a", "b"]), control: control))
        XCTAssertEqual(outcomes(events).count, 2)
    }
}
