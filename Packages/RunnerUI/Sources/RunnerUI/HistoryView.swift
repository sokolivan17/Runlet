import SwiftUI
import RunnerFeatures
import RunnerPersistence

@MainActor
public struct HistoryView: View {
    @State private var viewModel: HistoryViewModel
    @State private var confirmingClear = false

    public init(viewModel: HistoryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.items.isEmpty {
                ContentUnavailableView("No runs yet", systemImage: "clock",
                                       description: Text("Finished runs appear here."))
            } else {
                List {
                    ForEach(viewModel.items) { run in
                        Button { viewModel.select(run) } label: { HistoryRow(run: run) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let targets = offsets.map { viewModel.items[$0] }
                        Task { for target in targets { await viewModel.delete(target) } }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear", systemImage: "trash", role: .destructive) { confirmingClear = true }
                    .disabled(viewModel.items.isEmpty)
            }
        }
        .confirmationDialog("Delete all runs?", isPresented: $confirmingClear) {
            Button("Delete all", role: .destructive) { Task { await viewModel.clear() } }
        }
        .errorAlert($viewModel.errorMessage)
        .task { await viewModel.load() }
    }
}

private struct HistoryRow: View {
    let run: RunRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(run.collectionName).font(.headline)
            Text("\(run.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(run.summary.passed) passed · \(run.summary.failed) failed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
