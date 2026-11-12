//
//  RunletApp.swift
//  Runlet
//
//  Created by Ivan Sokol on 11.11.2026.
//

import SwiftUI
import Observation
import RunnerEngine
import RunnerFeatures
import RunnerPersistence
import RunnerUI

/// Owns the navigation path and builds screens with their view models.
/// View models talk to it only through the *Coordinating protocols.
@MainActor @Observable
final class AppCoordinator: CollectionsCoordinating, RunnerCoordinating, HistoryCoordinating {
    var path: [Route] = []

    @ObservationIgnored private let repository: LiveRepository
    @ObservationIgnored private let engine: RunEngine

    init(repository: LiveRepository, engine: RunEngine = RunEngine()) {
        self.repository = repository
        self.engine = engine
    }

    // MARK: Navigation (called by view models)

    func showRunner(for collection: CollectionRecord) { path.append(.runner(collection)) }
    func showEnvironments() { path.append(.environments) }
    func showHistory() { path.append(.history) }
    func showRunDetail(_ run: RunRecord) { path.append(.runDetail(run)) }

    // MARK: Screen factories

    func rootView() -> some View {
        CollectionsView(viewModel: CollectionsViewModel(repository: repository, coordinator: self))
    }

    @ViewBuilder
    func destination(for route: Route) -> some View {
        switch route {
        case .runner(let collection):
            RunnerView(viewModel: RunnerViewModel(
                collection: collection, collections: repository, environments: repository,
                history: repository, engine: engine, coordinator: self))
        case .runDetail(let run):
            RunDetailView(viewModel: RunDetailViewModel(run: run))
        case .environments:
            EnvironmentsView(viewModel: EnvironmentsViewModel(repository: repository))
        case .history:
            HistoryView(viewModel: HistoryViewModel(repository: repository, coordinator: self))
        }
    }
}
