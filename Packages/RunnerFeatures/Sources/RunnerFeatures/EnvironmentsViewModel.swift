import Foundation
import Observation
import RunnerPersistence

@MainActor @Observable
public final class EnvironmentsViewModel {
    public private(set) var items: [EnvironmentRecord] = []
    public var errorMessage: String?

    @ObservationIgnored private let repository: any EnvironmentsRepository

    public init(repository: any EnvironmentsRepository) { self.repository = repository }

    /// Parses `key=value` lines. Blank lines, `#` comments and lines without a key are ignored.
    public nonisolated static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            result[key] = trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    public nonisolated static func format(_ variables: [String: String]) -> String {
        variables.keys.sorted().map { "\($0)=\(variables[$0] ?? "")" }.joined(separator: "\n")
    }

    public func load() async {
        do { items = try await repository.environments() }
        catch { errorMessage = UserFacingError.message(for: error) }
    }

    /// Creates or updates an environment from the editor's text. Returns `true` on success.
    @discardableResult
    public func save(id: UUID? = nil, name: String, variablesText: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Name is required."
            return false
        }
        do {
            _ = try await repository.saveEnvironment(id: id, name: trimmed, variables: Self.parse(variablesText))
            items = try await repository.environments()
            return true
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return false
        }
    }

    public func delete(_ environment: EnvironmentRecord) async {
        do {
            try await repository.deleteEnvironment(id: environment.id)
            items.removeAll { $0.id == environment.id }
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
