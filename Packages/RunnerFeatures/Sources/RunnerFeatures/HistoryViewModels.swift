import Foundation
import Observation
import RunnerEngine
import RunnerPersistence

@MainActor @Observable
public final class HistoryViewModel {
    public private(set) var items: [RunRecord] = []
    public var errorMessage: String?

    @ObservationIgnored public weak var coordinator: (any HistoryCoordinating)?
    @ObservationIgnored private let repository: any HistoryRepository

    public init(repository: any HistoryRepository, coordinator: (any HistoryCoordinating)? = nil) {
        self.repository = repository
        self.coordinator = coordinator
    }

    public func load() async {
        do { items = try await repository.runs(limit: 100) }
        catch { errorMessage = UserFacingError.message(for: error) }
    }

    public func delete(_ run: RunRecord) async {
        do {
            try await repository.deleteRun(id: run.id)
            items.removeAll { $0.id == run.id }
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    public func clear() async {
        do {
            try await repository.clearHistory()
            items = []
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    public func select(_ run: RunRecord) { coordinator?.showRunDetail(run) }
}

@MainActor @Observable
public final class RunDetailViewModel {
    public let run: RunRecord
    public var showFailedOnly = false

    public init(run: RunRecord) { self.run = run }

    public var visibleOutcomes: [RequestOutcome] {
        showFailedOnly ? run.outcomes.filter { !$0.isSuccess } : run.outcomes
    }

    public var passRate: Double {
        run.summary.total == 0 ? 0 : Double(run.summary.passed) / Double(run.summary.total)
    }

    public var averageDuration: TimeInterval {
        run.outcomes.isEmpty ? 0 : run.outcomes.map(\.duration).reduce(0, +) / Double(run.outcomes.count)
    }
}
