import XCTest
@testable import RunnerCore

final class VariableResolverTests: XCTestCase {
    func testReplacesSimpleVariable() {
        let resolver = VariableResolver(scopes: [["host": "api.example.com"]])
        let result = resolver.resolve("https://{{host}}/users")
        XCTAssertEqual(result.value, "https://api.example.com/users")
        XCTAssertTrue(result.unresolved.isEmpty)
    }

    func testFirstScopeHasPriority() {
        let resolver = VariableResolver(scopes: [["env": "staging"], ["env": "prod"]])
        XCTAssertEqual(resolver.resolve("{{env}}").value, "staging")
    }

    func testToleratesWhitespaceInsideBraces() {
        let resolver = VariableResolver(scopes: [["id": "42"]])
        XCTAssertEqual(resolver.resolve("/items/{{ id }}").value, "/items/42")
    }

    func testResolvesNestedVariables() {
        let resolver = VariableResolver(scopes: [["base": "https://{{host}}", "host": "example.com"]])
        XCTAssertEqual(resolver.resolve("{{base}}/ping").value, "https://example.com/ping")
    }

    func testReportsUnresolvedAndKeepsPlaceholder() {
        let resolver = VariableResolver(scopes: [["a": "1"]])
        let result = resolver.resolve("{{a}}-{{b}}-{{b}}-{{c}}")
        XCTAssertEqual(result.value, "1-{{b}}-{{b}}-{{c}}")
        XCTAssertEqual(result.unresolved, ["b", "c"])
    }

    func testCyclicVariablesTerminate() {
        let resolver = VariableResolver(scopes: [["a": "{{b}}", "b": "{{a}}"]])
        let result = resolver.resolve("{{a}}")
        XCTAssertFalse(result.value.isEmpty)
    }

    func testUnclosedBracesAreLeftAsIs() {
        let resolver = VariableResolver(scopes: [["a": "1"]])
        XCTAssertEqual(resolver.resolve("x {{a").value, "x {{a")
    }
}
