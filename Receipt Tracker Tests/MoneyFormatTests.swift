//
//  MoneyFormatTests.swift
//  Receipt Tracker Tests
//
//  Amounts show as whole dinars, rounded half up — a day's total and the
//  receipts under it must agree.
//

import Testing
import Foundation
@testable import Receipt_Tracker

struct MoneyFormatTests {

    private func d(_ string: String) -> Decimal { Decimal(string: string)! }

    @Test func roundsToNearestDinar() {
        #expect(MoneyFormat.grouped(d("2720.97")) == "2.721")
        #expect(MoneyFormat.grouped(d("2720.49")) == "2.720")
        #expect(MoneyFormat.grouped(d("2720.50")) == "2.721")
        #expect(MoneyFormat.grouped(d("0.4")) == "0")
    }

    @Test func signedKeepsMinusAndRounds() {
        #expect(MoneyFormat.signed(d("-49814.6")) == "-49.815")
        #expect(MoneyFormat.signed(d("-0.4")) == "0")
        #expect(MoneyFormat.signed(d("45000")) == "45.000")
    }

    @Test func currencyStringsMatchGrouped() {
        #expect(d("2720.97").asRSD == "2.721 RSD")
        #expect(d("-1500.5").asRSD == "-1.501 RSD")
    }
}
