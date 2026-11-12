import Foundation

/// Pause / resume / stop switch shared between the UI and a running `RunEngine`.
public actor RunControl {
    private var isPaused = false
    private var isStopped = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func pause() { isPaused = true }

    public func resume() {
        isPaused = false
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }

    public func stop() {
        isStopped = true
        resume()
    }

    /// Called by the engine between requests. Suspends while paused; returns `false` once stopped.
    func checkpoint() async -> Bool {
        while isPaused && !isStopped {
            await withCheckedContinuation { waiters.append($0) }
        }
        return !isStopped
    }
}
