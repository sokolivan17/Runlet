import SwiftUI
import RunnerFeatures
import RunnerPersistence

@MainActor
public struct EnvironmentsView: View {
    private struct EditorTarget: Identifiable {
        let id = UUID()
        let environment: EnvironmentRecord?
    }

    @State private var viewModel: EnvironmentsViewModel
    @State private var editorTarget: EditorTarget?

    public init(viewModel: EnvironmentsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.items.isEmpty {
                ContentUnavailableView("No environments", systemImage: "slider.horizontal.3",
                                       description: Text("Environments override collection variables during a run."))
            } else {
                List {
                    ForEach(viewModel.items) { environment in
                        Button { editorTarget = EditorTarget(environment: environment) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(environment.name).font(.headline)
                                Text("\(environment.variables.count) variables")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let targets = offsets.map { viewModel.items[$0] }
                        Task { for target in targets { await viewModel.delete(target) } }
                    }
                }
            }
        }
        .navigationTitle("Environments")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { editorTarget = EditorTarget(environment: nil) }
            }
        }
        .sheet(item: $editorTarget) { target in
            EnvironmentEditor(viewModel: viewModel, environment: target.environment)
        }
        .errorAlert($viewModel.errorMessage)
        .task { await viewModel.load() }
    }
}

private struct EnvironmentEditor: View {
    let viewModel: EnvironmentsViewModel
    let environment: EnvironmentRecord?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var text: String

    init(viewModel: EnvironmentsViewModel, environment: EnvironmentRecord?) {
        self.viewModel = viewModel
        self.environment = environment
        _name = State(initialValue: environment?.name ?? "")
        _text = State(initialValue: EnvironmentsViewModel.format(environment?.variables ?? [:]))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Section("Variables (one key=value per line)") {
                    TextEditor(text: $text)
                        .font(.body.monospaced())
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle(environment == nil ? "New environment" : "Edit environment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save(id: environment?.id, name: name, variablesText: text) {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
}
