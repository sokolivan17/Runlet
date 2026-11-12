import Foundation
import RunnerCore

public enum RequestBuildError: Error, Equatable, LocalizedError {
    case unresolvedVariables([String])
    case invalidURL(String)
    case unsupportedBody(String)

    public var errorDescription: String? {
        switch self {
        case .unresolvedVariables(let names): return "Unresolved variables: " + names.joined(separator: ", ")
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .unsupportedBody(let mode): return "Unsupported body mode: \(mode)"
        }
    }
}

/// Turns a `RequestDefinition` into a `URLRequest`, resolving `{{variables}}` along the way.
public struct RequestBuilder: Sendable {
    private let resolver: VariableResolver
    private let timeout: TimeInterval

    private static let formAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))

    public init(resolver: VariableResolver, timeout: TimeInterval = 30) {
        self.resolver = resolver
        self.timeout = timeout
    }

    public func build(_ definition: RequestDefinition) throws -> URLRequest {
        let urlText = try resolve(definition.url)
        guard var components = URLComponents(string: urlText),
              components.scheme != nil, components.host != nil else {
            throw RequestBuildError.invalidURL(urlText)
        }
        if case .apiKey(let name, let value, let inHeader)? = definition.auth, !inHeader {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: try resolve(name), value: try resolve(value)))
            components.queryItems = items
        }
        guard let url = components.url else { throw RequestBuildError.invalidURL(urlText) }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = definition.method

        for header in definition.headers where header.isEnabled {
            try request.setValue(resolve(header.value), forHTTPHeaderField: resolve(header.key))
        }
        try applyAuth(definition.auth, to: &request)
        try applyBody(definition.body, to: &request)
        return request
    }

    private func applyAuth(_ auth: RequestAuth?, to request: inout URLRequest) throws {
        switch auth {
        case .bearer(let token)?:
            try request.setValue("Bearer " + resolve(token), forHTTPHeaderField: "Authorization")
        case .basic(let username, let password)?:
            let credentials = try "\(resolve(username)):\(resolve(password))"
            request.setValue("Basic " + Data(credentials.utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        case .apiKey(let name, let value, let inHeader)? where inHeader:
            try request.setValue(resolve(value), forHTTPHeaderField: resolve(name))
        default:
            break
        }
    }

    private func applyBody(_ body: RequestBody?, to request: inout URLRequest) throws {
        switch body {
        case .raw(let text)?:
            request.httpBody = try Data(resolve(text).utf8)
        case .urlEncoded(let pairs)?:
            let encoded = try pairs.filter(\.isEnabled).map { pair in
                try formEncode(resolve(pair.key)) + "=" + formEncode(resolve(pair.value))
            }.joined(separator: "&")
            request.httpBody = Data(encoded.utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        case .unsupported(let mode)?:
            throw RequestBuildError.unsupportedBody(mode)
        case nil:
            break
        }
    }

    private func resolve(_ text: String) throws -> String {
        let result = resolver.resolve(text)
        guard result.unresolved.isEmpty else { throw RequestBuildError.unresolvedVariables(result.unresolved) }
        return result.value
    }

    private func formEncode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: Self.formAllowed) ?? text
    }
}
