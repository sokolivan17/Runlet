//
//  RunletApp.swift
//  Runlet
//
//  Created by Ivan Sokol on 11.11.2026.
//

import SwiftUI

struct RootView: View {
    @State var coordinator: AppCoordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            coordinator.rootView()
                .navigationDestination(for: Route.self) { route in
                    coordinator.destination(for: route)
                }
        }
    }
}
