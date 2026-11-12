import XCTest
import RunnerCore
@testable import RunnerEngine

final class RequestBuilderTests: XCTestCase {
    private let builder = RequestBuilder(resolver: VariableResolver(scopes: [["host": "example.com", "token": "abc"]]))

    private func definition(url: String = "https://{{host}}/p", headers: [KeyValue] = [],
                            body: RequestBody? = nil, auth: RequestAuth? = nil) -> RequestDefinition {
        RequestDefinition(id: "0", name: "T", method: "POST", url: url, headers: headers, body: body, auth: auth)
    }

    func testResolvesURLAndMethod() throws {
        let request = try builder.build(definition())
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/p")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testSkipsDisabledHeaders() throws {
        let request = try builder.build(definition(headers: [
            KeyValue(key: "X-On", value: "1"),
            KeyValue(key: "X-Off", value: "1", isEnabled: false)
        ]))
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-On"), "1")
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Off"))
    }

    func testBearerAuth() throws {
        let request = try builder.build(definition(auth: .bearer(token: "{{token}}")))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc")
    }

    func testBasicAuth() throws {
        let request = try builder.build(definition(auth: .basic(username: "user", password: "pass")))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Basic dXNlcjpwYXNz")
    }

    func testAPIKeyInQuery() throws {
        let request = try builder.build(definition(auth: .apiKey(name: "api_key", value: "K", inHeader: false)))
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/p?api_key=K")
    }

    func testURLEncodedBody() throws {
        let body = RequestBody.urlEncoded([KeyValue(key: "a", value: "1 2"), KeyValue(key: "b", value: "x&y")])
        let request = try builder.build(definition(body: body))
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "a=1%202&b=x%26y")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
    }

    func testUnresolvedVariableThrows() {
        XCTAssertThrowsError(try builder.build(definition(url: "https://{{missing}}/p"))) { error in
            XCTAssertEqual(error as? RequestBuildError, .unresolvedVariables(["missing"]))
        }
    }

    func testInvalidURLThrows() {
        XCTAssertThrowsError(try builder.build(definition(url: "not a url"))) { error in
            XCTAssertEqual(error as? RequestBuildError, .invalidURL("not a url"))
        }
    }

    func testUnsupportedBodyThrows() {
        XCTAssertThrowsError(try builder.build(definition(body: .unsupported(mode: "formdata")))) { error in
            XCTAssertEqual(error as? RequestBuildError, .unsupportedBody("formdata"))
        }
    }
}
