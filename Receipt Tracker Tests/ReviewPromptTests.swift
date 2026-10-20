//
//  ReviewPromptTests.swift
//  Receipt Tracker Tests
//
//  The rating ask: third clean scan onward, once per app version.
//

import Testing
import Foundation
@testable import Receipt_Tracker

struct ReviewPromptTests {

    private func freshDefaults() -> UserDefaults {
        let name = "ReviewPromptTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func asksOnTheThirdScanOnly() {
        let defaults = freshDefaults()
        #expect(!ReviewPrompt.recordScan(defaults: defaults, version: "1.0.2"))
        #expect(!ReviewPrompt.recordScan(defaults: defaults, version: "1.0.2"))
        #expect(ReviewPrompt.recordScan(defaults: defaults, version: "1.0.2"))
        #expect(!ReviewPrompt.recordScan(defaults: defaults, version: "1.0.2"))
    }

    @Test func asksAgainAfterAnUpdate() {
        let defaults = freshDefaults()
        for _ in 0..<3 { _ = ReviewPrompt.recordScan(defaults: defaults, version: "1.0.2") }
        #expect(ReviewPrompt.recordScan(defaults: defaults, version: "1.1"))
        #expect(!ReviewPrompt.recordScan(defaults: defaults, version: "1.1"))
    }

    @Test func rule() {
        #expect(!ReviewPrompt.shouldAsk(scans: 2, askedVersion: nil, version: "1.0"))
        #expect(ReviewPrompt.shouldAsk(scans: 3, askedVersion: nil, version: "1.0"))
        #expect(!ReviewPrompt.shouldAsk(scans: 9, askedVersion: "1.0", version: "1.0"))
    }
}
