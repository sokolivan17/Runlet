//
//  RunletApp.swift
//  Runlet
//
//  Created by Ivan Sokol on 11.11.2026.
//

import RunnerPersistence

/// Navigation destinations. Hashable by the identity of the payload, so records need not be Hashable.
enum Route: Hashable {
    case runner(CollectionRecord)
    case runDetail(RunRecord)
    case environments
    case history

    private var key: String {
        switch self {
        case .runner(let collection): return "runner-\(collection.id)"
        case .runDetail(let run): return "run-\(run.id)"
        case .environments: return "environments"
        case .history: return "history"
        }
    }

    static func == (lhs: Route, rhs: Route) -> Bool { lhs.key == rhs.key }

    func hash(into hasher: inout Hasher) { hasher.combine(key) }
}
