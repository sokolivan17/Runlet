import SwiftUI
import UniformTypeIdentifiers
import RunnerFeatures
import RunnerPersistence

@MainActor
public struct CollectionsView: View {
    @State private var viewModel: CollectionsViewModel
    @State private var isImporting = false

    public init(viewModel: CollectionsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.items.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No collections",
                    systemImage: "tray",
                    description: Text("Import a Postman Collection v2.x JSON file to get started."))
            } else {
                List {
                    ForEach(viewModel.items) { item in
                        Button { viewModel.select(item) } label: { CollectionRow(item: item) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let targets = offsets.map { viewModel.items[$0] }
                        Task { for target in targets { await viewModel.delete(target) } }
                    }
                }
            }
        }
        .navigationTitle("Collections")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Environments", systemImage: "slider.horizontal.3") { viewModel.openEnvironments() }
                Button("History", systemImage: "clock.arrow.circlepath") { viewModel.openHistory() }
                Button("Import", systemImage: "square.and.arrow.down") { isImporting = true }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { handleImport($0) }
        .errorAlert($viewModel.errorMessage)
        .task { await viewModel.load() }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        case .success(let url):
            Task { @MainActor in
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    await viewModel.importFile(data)
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct CollectionRow: View {
    let item: CollectionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name).font(.headline)
            Text("\(item.requestCount) requests · imported \(item.importedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
