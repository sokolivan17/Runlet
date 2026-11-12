import Foundation
import Observation
import RunnerPersistence

@MainActor @Observable
public final class CollectionsViewModel {
    public private(set) var items: [CollectionRecord] = []
    public private(set) var isLoading = false
    public var errorMessage: String?

    @ObservationIgnored public weak var coordinator: (any CollectionsCoordinating)?
    @ObservationIgnored private let repository: any CollectionsRepository

    public init(repository: any CollectionsRepository, coordinator: (any CollectionsCoordinating)? = nil) {
        self.repository = repository
        self.coordinator = coordinator
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do { items = try await repository.collections() }
        catch { errorMessage = UserFacingError.message(for: error) }
    }

    public func importFile(_ data: Data) async {
        do {
            _ = try await repository.importCollection(data)
            items = try await repository.collections()
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    public func delete(_ record: CollectionRecord) async {
        do {
            try await repository.deleteCollection(id: record.id)
            items.removeAll { $0.id == record.id }
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    public func select(_ record: CollectionRecord) { coordinator?.showRunner(for: record) }
    public func openEnvironments() { coordinator?.showEnvironments() }
    public func openHistory() { coordinator?.showHistory() }
}
