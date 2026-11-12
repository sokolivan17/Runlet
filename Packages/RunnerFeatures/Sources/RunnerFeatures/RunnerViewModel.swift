import Foundation
import Observation
import RunnerCore
import RunnerEngine
import RunnerPersistence

@MainActor @Observable
public final class RunnerViewModel {
    public enum State: Equatable {
        case idle, running, paused
        case finished(RunSummary)
    }

    public static let maxIterations = 100

    public let collection: CollectionRecord

    // Run settings, bound to the UI.
    public var iterations = 1
    public var delay: Double = 0
    public var stopOnFailure = false
    public var selectedEnvironmentID: UUID?
    public var errorMessage: String?

    public private(set) var environments: [EnvironmentRecord] = []
    public private(set) var state: State = .idle
    public private(set) var outcomes: [RequestOutcome] = []
    public private(set) var lastRun: RunRecord?

    @ObservationIgnored public weak var coordinator: (any RunnerCoordinating)?
    @ObservationIgnored private var control: RunControl?
    @ObservationIgnored private let collections: any CollectionsRepository
    @ObservationIgnored private let environmentsRepository: any EnvironmentsRepository
    @ObservationIgnored private let history: any HistoryRepository
    @ObservationIgnored private let engine: RunEngine

    public init(collection: CollectionRecord,
                collections: any CollectionsRepository,
                environments: any EnvironmentsRepository,
                history: any HistoryRepository,
                engine: RunEngine = RunEngine(),
                coordinator: (any RunnerCoordinating)? = nil) {
        self.collection = collection
        self.collections = collections
        self.environmentsRepository = environments
        self.history = history
        self.engine = engine
        self.coordinator = coordinator
    }

    // MARK: Derived state

    var clampedIterations: Int { min(max(iterations, 1), Self.maxIterations) }

    public var plannedRequests: Int { collection.requestCount * clampedIterations }

    public var progress: Double {
        plannedRequests == 0 ? 0 : min(1, Double(outcomes.count) / Double(plannedRequests))
    }

    public var isRunning: Bool {
        switch state {
        case .running, .paused: return true
        case .idle, .finished: return false
        }
    }

    // MARK: Actions

    public func prepare() async {
        do { environments = try await environmentsRepository.environments() }
        catch { errorMessage = UserFacingError.message(for: error) }
    }

    public func start() async {
        guard !isRunning else { return }
        errorMessage = nil
        outcomes = []
        lastRun = nil

        let loaded: RequestCollection
        do { loaded = try await collections.loadCollection(id: collection.id) }
        catch {
            errorMessage = UserFacingError.message(for: error)
            return
        }

        let variables = environments.first { $0.id == selectedEnvironmentID }?.variables ?? [:]
        let configuration = RunConfiguration(iterations: clampedIterations, delay: max(delay, 0),
                                             environment: variables, stopOnFailure: stopOnFailure)
        let control = RunControl()
        self.control = control
        let startedAt = Date()
        state = .running

        var summary: RunSummary?
        for await event in engine.run(loaded, configuration: configuration, control: control) {
            switch event {
            case .iterationStarted: break
            case .requestFinished(let outcome): outcomes.append(outcome)
            case .completed(let result): summary = result
            }
        }
        self.control = nil

        guard let summary else {
            state = .idle   // the surrounding task was cancelled before the run completed
            return
        }
        state = .finished(summary)
        do {
            lastRun = try await history.saveRun(collectionID: collection.id, collectionName: collection.name,
                                                startedAt: startedAt, summary: summary, outcomes: outcomes)
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    public func pause() async {
        await control?.pause()
        if state == .running { state = .paused }
    }

    public func resume() async {
        await control?.resume()
        if state == .paused { state = .running }
    }

    public func stop() async { await control?.stop() }

    public func openLastRun() {
        if let lastRun { coordinator?.showRunDetail(lastRun) }
    }
}
