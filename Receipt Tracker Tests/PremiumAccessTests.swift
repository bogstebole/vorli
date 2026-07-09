//
//  PremiumAccessTests.swift
//  Receipt Tracker Tests
//
//  Free-window logic: current and previous calendar month are always
//  viewable; anything older requires premium.
//

import Testing
import Foundation
@testable import Receipt_Tracker

struct PremiumAccessTests {

    private let calendar = Calendar.current
    // Fixed "now" so tests don't depend on the real clock.
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15))!

    private func month(_ year: Int, _ month: Int, day: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func currentMonthIsFree() {
        #expect(PremiumStore.isMonthUnlocked(month(2026, 7), isPremium: false, now: now))
    }

    @Test func previousMonthIsFree() {
        #expect(PremiumStore.isMonthUnlocked(month(2026, 6), isPremium: false, now: now))
        // First day of the previous month is inside the window too.
        #expect(PremiumStore.isMonthUnlocked(month(2026, 6, day: 1), isPremium: false, now: now))
    }

    @Test func twoMonthsAgoIsLocked() {
        #expect(!PremiumStore.isMonthUnlocked(month(2026, 5), isPremium: false, now: now))
        // Last moment of the month before the window is still locked.
        #expect(!PremiumStore.isMonthUnlocked(month(2026, 5, day: 31), isPremium: false, now: now))
    }

    @Test func lastYearIsLocked() {
        #expect(!PremiumStore.isMonthUnlocked(month(2025, 12), isPremium: false, now: now))
    }

    @Test func futureMonthsAreFree() {
        // Empty future months in the dashboard grid stay tappable.
        #expect(PremiumStore.isMonthUnlocked(month(2026, 11), isPremium: false, now: now))
    }

    @Test func premiumUnlocksEverything() {
        #expect(PremiumStore.isMonthUnlocked(month(2023, 1), isPremium: true, now: now))
        #expect(PremiumStore.isMonthUnlocked(month(2025, 12), isPremium: true, now: now))
    }

    @Test func januaryWindowCrossesYearBoundary() {
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        #expect(PremiumStore.isMonthUnlocked(month(2025, 12), isPremium: false, now: january))
        #expect(!PremiumStore.isMonthUnlocked(month(2025, 11), isPremium: false, now: january))
    }
}
