//
//  DebugLog.swift
//  Receipt Tracker
//
//  Console logging that is compiled out of release builds. Receipts are
//  financial data — their contents must never reach the release console.
//

/// Debug-only console log. The autoclosure means the message string is not
/// even constructed in release builds.
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
