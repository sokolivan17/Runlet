import Foundation

public struct KeyValue: Equatable, Sendable {
    public var key: String
    public var value: String
    public var isEnabled: Bool

    public init(key: String, value: String, isEnabled: Bool = true) {
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}

public enum RequestBody: Equatable, Sendable {
    case raw(String)
    case urlEncoded([KeyValue])
    case unsupported(mode: String)
}

public enum RequestAuth: Equatable, Sendable {
    case noAuth
    case bearer(token: String)
    case basic(username: String, password: String)
    case apiKey(name: String, value: String, inHeader: Bool)
}

public struct RequestDefinition: Equatable, Sendable, Identifiable {
    /// Deterministic index path inside the collection, e.g. "0.2".
    public let id: String
    public var name: String
    public var folderPath: [String]
    public var method: String
    public var url: String
    public var headers: [KeyValue]
    public var body: RequestBody?
    public var auth: RequestAuth?

    public init(id: String, name: String, folderPath: [String] = [], method: String = "GET",
                url: String, headers: [KeyValue] = [], body: RequestBody? = nil, auth: RequestAuth? = nil) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.auth = auth
    }
}

public indirect enum CollectionItem: Equatable, Sendable {
    case folder(name: String, items: [CollectionItem])
    case request(RequestDefinition)
}

public struct RequestCollection: Equatable, Sendable {
    public var name: String
    public var items: [CollectionItem]
    public var variables: [String: String]
    public var auth: RequestAuth?

    public init(name: String, items: [CollectionItem] = [], variables: [String: String] = [:], auth: RequestAuth? = nil) {
        self.name = name
        self.items = items
        self.variables = variables
        self.auth = auth
    }

    /// Requests in execution order. A request without its own auth inherits the collection's.
    public var allRequests: [RequestDefinition] {
        func walk(_ items: [CollectionItem]) -> [RequestDefinition] {
            items.flatMap { item -> [RequestDefinition] in
                switch item {
                case .folder(_, let children): return walk(children)
                case .request(let request): return [request]
                }
            }
        }
        return walk(items).map { request in
            var copy = request
            copy.auth = request.auth ?? auth
            return copy
        }
    }
}
