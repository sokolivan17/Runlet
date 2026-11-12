import XCTest
@testable import RunnerUI

final class FormattersTests: XCTestCase {
    func testDurationUsesMillisecondsBelowOneSecond() {
        XCTAssertEqual(Formatters.duration(0.12), "120 ms")
    }

    func testDurationUsesSecondsFromOneSecond() {
        XCTAssertEqual(Formatters.duration(1.5), "1.50 s")
    }

    func testPercentRounds() {
        XCTAssertEqual(Formatters.percent(0.756), "76%")
    }
}
