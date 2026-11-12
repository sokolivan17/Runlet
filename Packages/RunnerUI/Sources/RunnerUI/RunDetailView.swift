import SwiftUI
import RunnerFeatures

@MainActor
public struct RunDetailView: View {
    @State private var viewModel: RunDetailViewModel

    public init(viewModel: RunDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Pass rate", value: Formatters.percent(viewModel.passRate))
                LabeledContent("Passed", value: "\(viewModel.run.summary.passed)")
                LabeledContent("Failed", value: "\(viewModel.run.summary.failed)")
                LabeledContent("Total time", value: Formatters.duration(viewModel.run.summary.duration))
                LabeledContent("Average request", value: Formatters.duration(viewModel.averageDuration))
            }
            Section("Requests") {
                Toggle("Show failed only", isOn: $viewModel.showFailedOnly)
                ForEach(Array(viewModel.visibleOutcomes.enumerated()), id: \.offset) { _, outcome in
                    OutcomeRow(outcome: outcome)
                }
            }
        }
        .navigationTitle(viewModel.run.collectionName)
    }
}
