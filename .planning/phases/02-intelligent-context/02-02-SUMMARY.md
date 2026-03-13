---
plan: 02-02
phase: 02-intelligent-context
status: complete
completed: 2026-03-13
---

# Plan 02-02: SavingsGoal Data Model

## What Was Built

Added `SavingsGoal` SwiftData model and wired it end-to-end into the Vorli context pipeline. Goals now appear in JSON sent to the Anthropic API under `finansije.ciljevi`. Replaced the free-text `aktivniCilj` Settings field with a structured 3-goal form. Removed `aktivniCilj` from system prompt injection (data duplication eliminated).

## Key Files

### Modified
- `Receipt Tracker/Receipt.swift` — `@Model final class SavingsGoal` with naziv, ciljaniIznos, trenutniIznos, rok
- `Receipt Tracker/Receipt_TrackerApp.swift` — `SavingsGoal.self` added to ModelContainer schema
- `Receipt Tracker/VorliContextBuilder.swift` — `savingsGoals` parameter; finansije guard includes goals; ciljevi block with `max(0, months)` clamp
- `Receipt Tracker/VorliChatViewModel.swift` — `send()` and `sendQuickPrompt()` accept savingsGoals; threaded through all 3 buildContext branches
- `Receipt Tracker/VorliChatView.swift` — `@Query private var savingsGoals`; passed to submitInput() and QuickPromptRow
- `Receipt Tracker/SettingsSheet.swift` — structured 3-goal form replacing aktivniCilj text field
- `Receipt Tracker Tests/VorliContextBuilderTests.swift` — XCTFail stubs replaced with real CTX-03 assertions

## Test Results

VorliContextBuilderTests: 3/3 PASSED ✓
- testCiljeviBlock ✓
- testExpiredGoalClampedToZero ✓
- testFinansijeCreatedForGoalsOnly ✓

## Self-Check: PASSED
