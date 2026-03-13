import XCTest
@testable import Receipt_Tracker

final class TimeWindowTests: XCTestCase {
    func testAllCasesRoundTrip() {
        let rawValues = ["this_month", "last_month", "this_week", "last_week", "recent"]
        for raw in rawValues {
            XCTAssertNotNil(TimeWindow(rawValue: raw), "Expected TimeWindow for rawValue '\(raw)'")
        }
        XCTAssertEqual(TimeWindow.allCases.count, 5)
    }

    func testFallbackOnUnknownRawValue() {
        XCTAssertNil(TimeWindow(rawValue: "garbage"))
        XCTAssertNil(TimeWindow(rawValue: ""))
        XCTAssertNil(TimeWindow(rawValue: "RECENT"))  // case-sensitive
    }
}
