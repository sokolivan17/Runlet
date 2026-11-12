import Foundation
import RunnerCore

public struct RunConfiguration: Sendable {
    public var iterations: Int
    public var delay: TimeInterval
    public var timeout: TimeInterval
    public var environment: [String: String]
    public var stopOnFailure: Bool

    public init(iterations: Int = 1, delay: TimeInterval = 0, timeout: TimeInterval = 30,
                environment: [String: String] = [:], stopOnFailure: Bool = false) {
        self.iterations = iterations
        self.delay = delay
        self.timeout = timeout
        self.environment = environment
        self.stopOnFailure = stopOnFailure
    }
}

public struct RequestOutcome: Equatable, Sendable {
    public let iteration: Int
    public let requestID: String
    public let name: String
    public let method: String
    public let statusCode: Int?
    public let duration: TimeInterval
    public let responseSize: Int
    public let errorDescription: String?

    public init(iteration: Int, requestID: String, name: String, method: String, statusCode: Int?,
                duration: TimeInterval, responseSize: Int, errorDescription: String?) {
        self.iteration = iteration
        self.requestID = requestID
        self.name = name
        self.method = method
        self.statusCode = statusCode
        self.duration = duration
        self.responseSize = responseSize
        self.errorDescription = errorDescription
    }

    public var isSuccess: Bool {
        guard errorDescription == nil, let code = statusCode else { return false }
        return (200..<400).contains(code)
    }
}

public struct RunSummary: Equatable, Sendable {
    public let total: Int
    public let passed: Int
    public let failed: Int
    public let stoppedEarly: Bool
    public let duration: TimeInterval

    public init(total: Int, passed: Int, failed: Int, stoppedEarly: Bool, duration: TimeInterval) {
        self.total = total
        self.passed = passed
        self.failed = failed
        self.stoppedEarly = stoppedEarly
        self.duration = duration
    }
}

public enum RunEvent: Equatable, Sendable {
    case iterationStarted(Int)
    case requestFinished(RequestOutcome)
    case completed(RunSummary)
}

public final class RunEngine: Sendable {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    /// Runs the collection sequentially. Terminating the stream cancels the run.
    public func run(_ collection: RequestCollection,
                    configuration: RunConfiguration = RunConfiguration(),
                    control: RunControl = RunControl()) -> AsyncStream<RunEvent> {
        AsyncStream { continuation in
            let task = Task {
                let clock = ContinuousClock()
                let start = clock.now
                let requests = collection.allRequests
                let resolver = VariableResolver(scopes: [configuration.environment, collection.variables])
                var passed = 0
                var failed = 0
                var stoppedEarly = false

                iterations: for iteration in 1...max(1, configuration.iterations) {
                    continuation.yield(.iterationStarted(iteration))
                    for request in requests {
                        if !(await control.checkpoint()) || Task.isCancelled {
                            stoppedEarly = true
                            break iterations
                        }
                        let outcome = await self.execute(request, iteration: iteration,
                                                         resolver: resolver, timeout: configuration.timeout)
                        continuation.yield(.requestFinished(outcome))
                        if outcome.isSuccess { passed += 1 } else { failed += 1 }
                        if !outcome.isSuccess && configuration.stopOnFailure {
                            stoppedEarly = true
                            break iterations
                        }
                        if configuration.delay > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(configuration.delay * 1_000_000_000))
                        }
                    }
                }
                continuation.yield(.completed(RunSummary(
                    total: passed + failed, passed: passed, failed: failed,
                    stoppedEarly: stoppedEarly, duration: seconds(start.duration(to: clock.now)))))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func execute(_ request: RequestDefinition, iteration: Int,
                         resolver: VariableResolver, timeout: TimeInterval) async -> RequestOutcome {
        let clock = ContinuousClock()
        let start = clock.now
        func outcome(status: Int?, size: Int, error: String?) -> RequestOutcome {
            RequestOutcome(iteration: iteration, requestID: request.id, name: request.name,
                           method: request.method, statusCode: status,
                           duration: seconds(start.duration(to: clock.now)),
                           responseSize: size, errorDescription: error)
        }
        do {
            let urlRequest = try RequestBuilder(resolver: resolver, timeout: timeout).build(request)
            let (data, response) = try await transport.send(urlRequest)
            return outcome(status: response.statusCode, size: data.count, error: nil)
        } catch {
            return outcome(status: nil, size: 0, error: error.localizedDescription)
        }
    }
}

private func seconds(_ duration: Duration) -> TimeInterval {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
}
