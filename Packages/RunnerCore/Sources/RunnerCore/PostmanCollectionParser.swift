import Foundation

public enum CollectionParseError: Error, Equatable {
    case invalidJSON(String)
    case unsupportedSchema(String)
}

/// Parses Postman Collection v2.x JSON into domain models.
public struct PostmanCollectionParser: Sendable {
    public init() {}

    public func parse(_ data: Data) throws -> RequestCollection {
        let dto: CollectionDTO
        do {
            dto = try JSONDecoder().decode(CollectionDTO.self, from: data)
        } catch {
            throw CollectionParseError.invalidJSON(String(describing: error))
        }
        if let schema = dto.info.schema, !schema.contains("/v2.") {
            throw CollectionParseError.unsupportedSchema(schema)
        }
        var variables: [String: String] = [:]
        for variable in dto.variable ?? [] where !variable.key.isEmpty && !variable.disabled {
            variables[variable.key] = variable.value
        }
        return RequestCollection(
            name: dto.info.name,
            items: map(dto.item ?? [], indexPath: [], folderPath: []),
            variables: variables,
            auth: dto.auth.flatMap(mapAuth)
        )
    }

    // MARK: - Mapping

    private func map(_ items: [ItemDTO], indexPath: [Int], folderPath: [String]) -> [CollectionItem] {
        items.enumerated().compactMap { index, item in
            let path = indexPath + [index]
            let name = item.name ?? "Untitled"
            if let children = item.item {
                return .folder(name: name, items: map(children, indexPath: path, folderPath: folderPath + [name]))
            }
            guard let request = item.request else { return nil }
            return .request(RequestDefinition(
                id: path.map(String.init).joined(separator: "."),
                name: name,
                folderPath: folderPath,
                method: (request.method ?? "GET").uppercased(),
                url: request.url?.raw ?? "",
                headers: (request.header ?? []).map { KeyValue(key: $0.key, value: $0.value, isEnabled: !$0.disabled) },
                body: request.body.flatMap(mapBody),
                auth: request.auth.flatMap(mapAuth)
            ))
        }
    }

    private func mapBody(_ body: BodyDTO) -> RequestBody? {
        switch body.mode {
        case "raw": return .raw(body.raw ?? "")
        case "urlencoded":
            return .urlEncoded((body.urlencoded ?? []).map { KeyValue(key: $0.key, value: $0.value, isEnabled: !$0.disabled) })
        case nil: return nil
        case let mode?: return .unsupported(mode: mode)
        }
    }

    private func mapAuth(_ auth: AuthDTO) -> RequestAuth? {
        func value(_ list: [KeyValueDTO]?, _ key: String) -> String {
            list?.first { $0.key == key }?.value ?? ""
        }
        switch auth.type {
        case "noauth": return .noAuth
        case "bearer": return .bearer(token: value(auth.bearer, "token"))
        case "basic": return .basic(username: value(auth.basic, "username"), password: value(auth.basic, "password"))
        case "apikey":
            return .apiKey(name: value(auth.apikey, "key"), value: value(auth.apikey, "value"),
                           inHeader: value(auth.apikey, "in") != "query")
        default: return nil
        }
    }
}

// MARK: - Tolerant DTOs (Postman exports vary a lot)

private struct CollectionDTO: Decodable {
    struct Info: Decodable { let name: String; let schema: String? }
    let info: Info
    let item: [ItemDTO]?
    let variable: [KeyValueDTO]?
    let auth: AuthDTO?
}

private struct ItemDTO: Decodable {
    let name: String?
    let item: [ItemDTO]?
    let request: RequestDTO?
}

private struct RequestDTO: Decodable {
    let method: String?
    let header: [KeyValueDTO]?
    let url: URLDTO?
    let body: BodyDTO?
    let auth: AuthDTO?

    private enum CodingKeys: String, CodingKey { case method, header, url, body, auth }

    init(from decoder: Decoder) throws {
        // Postman allows `"request": "https://example.com"` as a shorthand GET.
        if let single = try? decoder.singleValueContainer(), let raw = try? single.decode(String.self) {
            method = nil; header = nil; url = URLDTO(raw: raw); body = nil; auth = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        method = try c.decodeIfPresent(String.self, forKey: .method)
        header = try? c.decodeIfPresent([KeyValueDTO].self, forKey: .header)
        url = try c.decodeIfPresent(URLDTO.self, forKey: .url)
        body = try c.decodeIfPresent(BodyDTO.self, forKey: .body)
        auth = try c.decodeIfPresent(AuthDTO.self, forKey: .auth)
    }
}

private struct URLDTO: Decodable {
    let raw: String

    init(raw: String) { self.raw = raw }

    private enum CodingKeys: String, CodingKey { case raw, host, path, scheme = "protocol" }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let string = try? single.decode(String.self) {
            raw = string
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try c.decodeIfPresent(String.self, forKey: .raw) {
            raw = value
            return
        }
        func parts(_ key: CodingKeys) -> [String] {
            if let list = try? c.decode([String].self, forKey: key) { return list }
            if let one = try? c.decode(String.self, forKey: key) { return [one] }
            return []
        }
        let scheme = (try? c.decode(String.self, forKey: .scheme)).map { $0 + "://" } ?? ""
        let path = parts(.path)
        raw = scheme + parts(.host).joined(separator: ".") + (path.isEmpty ? "" : "/" + path.joined(separator: "/"))
    }
}

private struct KeyValueDTO: Decodable {
    let key: String
    let value: String
    let disabled: Bool

    private enum CodingKeys: String, CodingKey { case key, value, disabled }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = (try? c.decode(String.self, forKey: .key)) ?? ""
        if let string = try? c.decode(String.self, forKey: .value) {
            value = string
        } else if let int = try? c.decode(Int.self, forKey: .value) {
            value = String(int)
        } else if let bool = try? c.decode(Bool.self, forKey: .value) {
            value = String(bool)
        } else {
            value = ""
        }
        disabled = (try? c.decode(Bool.self, forKey: .disabled)) ?? false
    }
}

private struct BodyDTO: Decodable {
    let mode: String?
    let raw: String?
    let urlencoded: [KeyValueDTO]?
}

private struct AuthDTO: Decodable {
    let type: String
    let bearer: [KeyValueDTO]?
    let basic: [KeyValueDTO]?
    let apikey: [KeyValueDTO]?
}
