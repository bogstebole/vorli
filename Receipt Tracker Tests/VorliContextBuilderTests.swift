import XCTest
@testable import Receipt_Tracker

final class VorliContextBuilderTests: XCTestCase {

    // MARK: - Helpers

    private func parseJSON(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    private func futureDate(monthsFromNow: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: monthsFromNow, to: Date()) ?? Date()
    }

    private func pastDate(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }

    // MARK: - Tests

    func testCiljeviBlock() throws {
        // GIVEN: one future savings goal
        let goal = Wish(
            naziv: "Odmor",
            cilj: Decimal(150_000),
            rok: futureDate(monthsFromNow: 6)
        )

        // WHEN: building context with that goal
        let json = VorliContextBuilder.build(
            currentReceipts: [],
            wishes: [goal]
        )

        // THEN: finansije.ciljevi contains one entry with the required keys
        let dict = try XCTUnwrap(parseJSON(json))
        let finansije = try XCTUnwrap(dict["finansije"] as? [String: Any])
        let ciljevi = try XCTUnwrap(finansije["ciljevi"] as? [[String: Any]])
        XCTAssertEqual(ciljevi.count, 1)

        let entry = try XCTUnwrap(ciljevi.first)
        XCTAssertEqual(entry["naziv"] as? String, "Odmor")
        XCTAssertNotNil(entry["cilj_rsd"])
        XCTAssertNotNil(entry["rok"])
        let preostalo = try XCTUnwrap(entry["preostalo_meseci"] as? Int)
        XCTAssertGreaterThan(preostalo, 0)
    }

    func testExpiredGoalClampedToZero() throws {
        // GIVEN: a goal whose deadline was yesterday
        let goal = Wish(
            naziv: "Laptop",
            cilj: Decimal(80_000),
            rok: pastDate(daysAgo: 1)
        )

        // WHEN: building context
        let json = VorliContextBuilder.build(
            currentReceipts: [],
            wishes: [goal]
        )

        // THEN: preostalo_meseci is 0 (never negative)
        let dict = try XCTUnwrap(parseJSON(json))
        let finansije = try XCTUnwrap(dict["finansije"] as? [String: Any])
        let ciljevi = try XCTUnwrap(finansije["ciljevi"] as? [[String: Any]])
        let entry = try XCTUnwrap(ciljevi.first)
        let preostalo = try XCTUnwrap(entry["preostalo_meseci"] as? Int)
        XCTAssertEqual(preostalo, 0, "Expired goal must have preostalo_meseci == 0, not negative")
    }

    func testFinansijeCreatedForGoalsOnly() throws {
        // GIVEN: no budget, no income, but one goal present
        let goal = Wish(
            naziv: "Kola",
            cilj: Decimal(500_000),
            rok: futureDate(monthsFromNow: 24)
        )

        // WHEN: building context with budget=nil and no userProfile
        let json = VorliContextBuilder.build(
            currentReceipts: [],
            budget: nil,
            userProfile: nil,
            wishes: [goal]
        )

        // THEN: finansije key is present
        let dict = try XCTUnwrap(parseJSON(json))
        XCTAssertNotNil(dict["finansije"], "finansije block must be created even when only goals are present")
        let finansije = try XCTUnwrap(dict["finansije"] as? [String: Any])
        XCTAssertNotNil(finansije["ciljevi"])
    }
}
