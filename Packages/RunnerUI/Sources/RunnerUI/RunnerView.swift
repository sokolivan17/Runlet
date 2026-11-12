import SwiftUI
import RunnerFeatures

@MainActor
public struct RunnerView: View {
    @State private var viewModel: RunnerViewModel

    public init(viewModel: RunnerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        List {
            Section("Settings") {
                Stepper(value: $viewModel.iterations, in: 1...RunnerViewModel.maxIterations) {
                    Text("Iterations: \(viewModel.iterations)")
                }
                Stepper(value: $viewModel.delay, in: 0...10, step: 0.5) {
                    Text("Delay: \(Formatters.seconds(viewModel.delay))")
                }
                Toggle("Stop on first failure", isOn: $viewModel.stopOnFailure)
                Picker("Environment", selection: $viewModel.selectedEnvironmentID) {
                    Text("None").tag(UUID?.none)
                    ForEach(viewModel.environments) { environment in
                        Text(environment.name).tag(UUID?.some(environment.id))
                    }
                }
            }
            .disabled(viewModel.isRunning)

            Section {
                controls
                ProgressView(value: viewModel.progress)
                if case .finished(let summary) = viewModel.state {
                    LabeledContent("Result", value: "\(summary.passed) passed · \(summary.failed) failed")
                    if summary.stoppedEarly {
                        Text("Run was stopped early.").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("View details", systemImage: "list.bullet.rectangle") { viewModel.openLastRun() }
                        .disabled(viewModel.lastRun == nil)
                }
            }

            if !viewModel.outcomes.isEmpty {
                Section("Results") {
                    ForEach(Array(viewModel.outcomes.enumerated()), id: \.offset) { _, outcome in
                        OutcomeRow(outcome: outcome)
                    }
                }
            }
        }
        .navigationTitle(viewModel.collection.name)
        .errorAlert($viewModel.errorMessage)
        .task { await viewModel.prepare() }
    }

    @ViewBuilder
    private var controls: some View {
        switch viewModel.state {
        case .idle, .finished:
            Button("Run collection", systemImage: "play.fill") { Task { await viewModel.start() } }
        case .running:
            HStack {
                Button("Pause", systemImage: "pause.fill") { Task { await viewModel.pause() } }
                Spacer()
                Button("Stop", systemImage: "stop.fill", role: .destructive) { Task { await viewModel.stop() } }
            }
            .buttonStyle(.borderless)
        case .paused:
            HStack {
                Button("Resume", systemImage: "play.fill") { Task { await viewModel.resume() } }
                Spacer()
                Button("Stop", systemImage: "stop.fill", role: .destructive) { Task { await viewModel.stop() } }
            }
            .buttonStyle(.borderless)
        }
    }
}
