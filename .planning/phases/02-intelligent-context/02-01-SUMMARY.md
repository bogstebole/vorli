---
phase: 02-intelligent-context
plan: 01
subsystem: testing
tags: [xctest, tdd, red-phase, unit-tests]

# Dependency graph
requires: []
provides:
  - XCTest bundle "Receipt Tracker Tests" with failing stubs for CTX-03, CTX-04, CTX-05
  - VorliContextBuilderTests with 3 stubs for ciljevi block, expired goal clamp, finansije guard
  - TimeWindowTests with 2 stubs for TimeWindow enum round-trip and fallback
  - VorliServiceTests with 2 stubs for KATEGORIZACIJA section in buildSystemPrompt()
affects:
  - 02-02 (SavingsGoal / CTX-03 implementation)
  - 02-03 (KATEGORIZACIJA / CTX-05 implementation)
  - 02-04 (TimeWindow / CTX-04 implementation)

# Tech tracking
tech-stack:
  added: [XCTest, @testable import Receipt_Tracker]
  patterns: [RED-phase TDD stubs with XCTFail bodies, no forward-references to unimplemented types]

key-files:
  created:
    - "Receipt Tracker Tests/VorliContextBuilderTests.swift"
    - "Receipt Tracker Tests/TimeWindowTests.swift"
    - "Receipt Tracker Tests/VorliServiceTests.swift"
  modified: []

key-decisions:
  - "Used XCTFail stubs (not forward type references) to keep test files compile-clean while marking RED state"
  - "Ran tests on iPhone 17 simulator (iOS 26.2) — iPhone 16 not available in this Xcode installation"

patterns-established:
  - "RED stubs: XCTFail('CTX-XX: [feature] not yet implemented — implement in Plan NN') as single stub body"
  - "All XCTest files use @testable import Receipt_Tracker; final class inherits XCTestCase"

requirements-completed: [CTX-03, CTX-04, CTX-05]

# Metrics
duration: 10min
completed: 2026-03-13
---

# Phase 2 Plan 01: RED Test Stubs for Intelligent Context Summary

**XCTest bundle "Receipt Tracker Tests" established with 7 compile-clean failing stubs covering CTX-03 (SavingsGoal/ciljevi), CTX-04 (TimeWindow enum), and CTX-05 (KATEGORIZACIJA system prompt)**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-13T06:27:00Z
- **Completed:** 2026-03-13T06:37:00Z
- **Tasks:** 2 (Task 1 by user; Task 2 by agent)
- **Files modified:** 3 created

## Accomplishments

- XCTest bundle target "Receipt Tracker Tests" confirmed operational (scheme added by user in Xcode GUI)
- Three test files written with XCTFail-only stubs — all 7 tests compile and fail as expected
- Plans 02, 03, 04 now have a working `xcodebuild test` command to assert GREEN against

## Task Commits

1. **Task 1: Add XCTest unit test bundle target** — completed manually by user (no commit; Xcode project file modified by GUI)
2. **Task 2: Write RED test stubs for CTX-03, CTX-04, CTX-05** — `29d6b02` (test)

**Plan metadata:** (see final docs commit below)

## Files Created/Modified

- `Receipt Tracker Tests/VorliContextBuilderTests.swift` — 3 failing stubs for CTX-03 (ciljevi block, expired goal clamp, finansije guard)
- `Receipt Tracker Tests/TimeWindowTests.swift` — 2 failing stubs for CTX-04 (enum round-trip, fallback)
- `Receipt Tracker Tests/VorliServiceTests.swift` — 2 failing stubs for CTX-05 (KATEGORIZACIJA section, merchant names)

## Decisions Made

- Used `XCTFail("CTX-XX: ...")` stub bodies instead of forward-referencing non-existent types (SavingsGoal, TimeWindow) — this keeps all files compile-clean, satisfying the Nyquist requirement
- Simulator target adjusted from iPhone 16 to iPhone 17 (iOS 26.2) — iPhone 16 not available in installed Xcode

## Deviations from Plan

None - plan executed exactly as written (destination simulator adjusted automatically per available devices).

## Issues Encountered

- `xcodebuild test -destination "platform=iOS Simulator,name=iPhone 16"` failed — no iPhone 16 simulator installed. Used iPhone 17 (iOS 26.2) instead. No plan impact.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Test infrastructure is live; Plans 02, 03, and 04 can each use `xcodebuild test -scheme "Receipt Tracker Tests" -destination "platform=iOS Simulator,name=iPhone 17"` as their automated verify command
- GREEN for each CTX requirement will be achieved by the corresponding implementation plan

---
*Phase: 02-intelligent-context*
*Completed: 2026-03-13*
