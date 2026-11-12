import Foundation

public struct Resolution: Equatable, Sendable {
    public let value: String
    /// Names that had no value in any scope; their `{{name}}` placeholders stay in `value`.
    public let unresolved: [String]
}

/// Substitutes `{{name}}` placeholders. Scopes are ordered by priority: the first scope wins.
public struct VariableResolver: Sendable {
    private let scopes: [[String: String]]
    private let maxDepth = 5

    public init(scopes: [[String: String]]) {
        self.scopes = scopes
    }

    public func resolve(_ text: String) -> Resolution {
        var current = text
        var missing: [String] = []
        // Several passes allow variables that reference other variables; the cap stops cycles.
        for _ in 0..<maxDepth {
            let pass = substitute(current)
            current = pass.text
            missing = pass.missing
            if !pass.replacedAny { break }
        }
        return Resolution(value: current, unresolved: missing)
    }

    private func lookup(_ name: String) -> String? {
        for scope in scopes {
            if let value = scope[name] { return value }
        }
        return nil
    }

    private func substitute(_ text: String) -> (text: String, missing: [String], replacedAny: Bool) {
        var result = ""
        var missing: [String] = []
        var replacedAny = false
        var index = text.startIndex

        while index < text.endIndex {
            guard let open = text.range(of: "{{", range: index..<text.endIndex),
                  let close = text.range(of: "}}", range: open.upperBound..<text.endIndex) else {
                result += text[index...]
                break
            }
            result += text[index..<open.lowerBound]
            let name = text[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            if let value = lookup(name) {
                result += value
                replacedAny = true
            } else {
                result += text[open.lowerBound..<close.upperBound]
                if !missing.contains(name) { missing.append(name) }
            }
            index = close.upperBound
        }
        return (result, missing, replacedAny)
    }
}
