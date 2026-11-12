import XCTest
@testable import RunnerCore

final class PostmanCollectionParserTests: XCTestCase {
    private let sample = #"""
    {
      "info": {"name": "Demo", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"},
      "variable": [{"key": "baseUrl", "value": "https://api.example.com"}],
      "auth": {"type": "bearer", "bearer": [{"key": "token", "value": "{{token}}", "type": "string"}]},
      "item": [
        {"name": "Users", "item": [
          {"name": "List", "request": {"method": "get",
            "header": [{"key": "Accept", "value": "application/json"}, {"key": "X-Off", "value": "1", "disabled": true}],
            "url": {"raw": "{{baseUrl}}/users?page=1"}}},
          {"name": "Create", "request": {"method": "POST", "url": "{{baseUrl}}/users",
            "body": {"mode": "raw", "raw": "{\"name\":\"A\"}"}}}
        ]},
        {"name": "Ping", "request": "https://example.com/ping"}
      ]
    }
    """#

    private func parse(_ json: String) throws -> RequestCollection {
        try PostmanCollectionParser().parse(Data(json.utf8))
    }

    func testParsesNameAndVariables() throws {
        let collection = try parse(sample)
        XCTAssertEqual(collection.name, "Demo")
        XCTAssertEqual(collection.variables["baseUrl"], "https://api.example.com")
    }

    func testFlattensNestedFoldersInOrder() throws {
        let requests = try parse(sample).allRequests
        XCTAssertEqual(requests.map(\.name), ["List", "Create", "Ping"])
        XCTAssertEqual(requests.map(\.id), ["0.0", "0.1", "1"])
        XCTAssertEqual(requests[0].folderPath, ["Users"])
    }

    func testParsesMethodHeadersAndDisabledFlag() throws {
        let list = try parse(sample).allRequests[0]
        XCTAssertEqual(list.method, "GET")
        XCTAssertEqual(list.url, "{{baseUrl}}/users?page=1")
        XCTAssertEqual(list.headers.count, 2)
        XCTAssertFalse(list.headers[1].isEnabled)
    }

    func testParsesRawBodyAndStringUrl() throws {
        let create = try parse(sample).allRequests[1]
        XCTAssertEqual(create.url, "{{baseUrl}}/users")
        XCTAssertEqual(create.body, .raw(#"{"name":"A"}"#))
    }

    func testSupportsShorthandStringRequest() throws {
        let ping = try parse(sample).allRequests[2]
        XCTAssertEqual(ping.method, "GET")
        XCTAssertEqual(ping.url, "https://example.com/ping")
    }

    func testRequestsInheritCollectionAuth() throws {
        let requests = try parse(sample).allRequests
        XCTAssertTrue(requests.allSatisfy { $0.auth == .bearer(token: "{{token}}") })
    }

    func testRejectsV1Schema() {
        let json = #"{"info": {"name": "Old", "schema": "https://schema.getpostman.com/json/collection/v1.0.0/collection.json"}, "item": []}"#
        XCTAssertThrowsError(try parse(json)) { error in
            guard case CollectionParseError.unsupportedSchema = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRejectsInvalidJSON() {
        XCTAssertThrowsError(try parse("not json")) { error in
            guard case CollectionParseError.invalidJSON = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
