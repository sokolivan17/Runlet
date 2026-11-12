import RunnerPersistence

// Navigation contracts. View models only know these protocols; the concrete
// AppCoordinator (in the app target) decides how screens are actually presented.

@MainActor
public protocol CollectionsCoordinating: AnyObject {
    func showRunner(for collection: CollectionRecord)
    func showEnvironments()
    func showHistory()
}

@MainActor
public protocol RunnerCoordinating: AnyObject {
    func showRunDetail(_ run: RunRecord)
}

@MainActor
public protocol HistoryCoordinating: AnyObject {
    func showRunDetail(_ run: RunRecord)
}
