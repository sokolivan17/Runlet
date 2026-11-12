//
//  RunletApp.swift
//  Runlet
//
//  Created by Ivan Sokol on 11.11.2026.
//

import SwiftUI
import RunnerPersistence
import RunnerFeatures

@main
struct RunletApp: App {
    @State private var coordinator: AppCoordinator?
    @State private var startupError: String?

    init() {
        do {
            let store = try RunnerStore.make()
            _coordinator = State(initialValue: AppCoordinator(repository: LiveRepository(store: store)))
            _startupError = State(initialValue: nil)
        } catch {
            _coordinator = State(initialValue: nil)
            _startupError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let coordinator {
                RootView(coordinator: coordinator)
            } else {
                ContentUnavailableView("Could not open the database", systemImage: "exclamationmark.triangle",
                                       description: Text(startupError ?? "Unknown error"))
            }
        }
    }
}
