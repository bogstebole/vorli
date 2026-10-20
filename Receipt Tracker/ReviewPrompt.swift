//
//  ReviewPrompt.swift
//  Receipt Tracker
//
//  When to ask for an App Store rating. Ratings are the one ranking signal a
//  new app can move by itself, but asking too early — or mid-task — earns
//  low ones. So the ask comes after the third receipt that scanned cleanly,
//  once the receipt is on screen, and at most once per app version. iOS adds
//  its own cap on top (three prompts a year) and may show nothing at all.
//

import Foundation

enum ReviewPrompt {
    /// Successful QR scans before the first ask.
    static let scansBeforeAsking = 3

    /// Long enough for the scanned receipt to land and be read first.
    static let delay: Duration = .seconds(2)

    private static let scanCountKey = "reviewPromptScanCount"
    private static let askedVersionKey = "reviewPromptAskedVersion"

    /// Records a successful scan. True when this is the moment to ask.
    static func recordScan(
        defaults: UserDefaults = .standard,
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    ) -> Bool {
        let count = defaults.integer(forKey: scanCountKey) + 1
        defaults.set(count, forKey: scanCountKey)
        guard shouldAsk(scans: count, askedVersion: defaults.string(forKey: askedVersionKey), version: version) else {
            return false
        }
        defaults.set(version, forKey: askedVersionKey)
        return true
    }

    static func shouldAsk(scans: Int, askedVersion: String?, version: String) -> Bool {
        scans >= scansBeforeAsking && askedVersion != version
    }
}
