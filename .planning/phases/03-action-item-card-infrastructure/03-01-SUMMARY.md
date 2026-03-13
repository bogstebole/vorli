---
phase: 03-action-item-card-infrastructure
plan: 01
subsystem: api
tags: [swift, swiftdata, xctest, tdd, codable, observable, vorli]

# Dependency graph
requires:
  - phase: 02-intelligent-context
    provides: VorliMessage, VorliChatViewModel, VorliService streaming infrastructure

provides:
  - VorliCardPayload struct (CardType, ActionState enums) in VorliService.swift
  - VorliMessageContent enum (.text/.card) with discriminated Codable + backward-compat decode
  - VorliMessage.textContent computed property
  - VorliChatViewModel.emitCard() method
  - VorliChatViewModel.updateCardState() method
  - VorliMessageTests: 4 green tests (roundtrip, backward-compat, emitCard, updateCardState)

affects:
  - 03-02: card UI rendering (reads VorliMessage.content as VorliMessageContent)
  - 03-03: PDF generation (uses emitCard + updateCardState lifecycle)
  - All future phases that append messages to VorliChatViewModel

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Discriminated union Codable: VorliMessageContent uses keyed container with `type` discriminator
    - Backward-compat decode at VorliMessage level: tries VorliMessageContent first, falls back to bare String
    - TDD with async XCTest methods for @MainActor-isolated ViewModel tests

key-files:
  created:
    - Receipt Tracker Tests/VorliMessageTests.swift
  modified:
    - Receipt Tracker/VorliService.swift
    - Receipt Tracker/VorliChatViewModel.swift
    - Receipt Tracker/VorliChatView.swift

key-decisions:
  - "Backward-compat decode placed in VorliMessage.init(from:) — not in VorliMessageContent — because old JSON had 'content: String' as a scalar VorliMessage field, which VorliMessageContent's keyed-container decoder cannot handle"
  - "VorliMessageTests 3+4 use async test methods to avoid @MainActor isolation crash with XCTest non-async methods on simulator clones"
  - "VorliChatView.onChange uses textContent (String) instead of content (VorliMessageContent) to keep scroll-trigger working without needing Equatable conformance changes"

patterns-established:
  - "VorliMessageContent enum: .text(String) | .card(VorliCardPayload) — all ViewModel/View code uses .textContent for text access"
  - "Card lifecycle: emitCard(.loading) → updateCardState(id, .ready) — triggered by async work completion"

requirements-completed: [UX-01, UX-02]

# Metrics
duration: 22min
completed: 2026-03-13
---

# Phase 3 Plan 01: VorliMessage Typed Content Model Summary

**VorliMessageContent enum with discriminated Codable replaces String content in VorliMessage, enabling card payloads (VorliCardPayload) alongside text, with backward-compatible decode of persisted sessions and green TDD test suite**

## Performance

- **Duration:** 22 min
- **Started:** 2026-03-13T12:37:07Z
- **Completed:** 2026-03-13T12:59:04Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- VorliMessage.content changed from String to VorliMessageContent enum with .text/.card cases
- VorliCardPayload struct defined with CardType (pdf, shoppingList) and ActionState (loading, ready, disabled) enums
- Backward-compat Codable migration: old persisted sessions with `"content": "string"` decode cleanly as .text
- emitCard() and updateCardState() methods added to VorliChatViewModel
- Four unit tests passing green (Codable roundtrip, legacy decode, emitCard, updateCardState)

## Task Commits

Each task was committed atomically:

1. **Task 1: RED test stubs for VorliMessageTests** - `a0e6936` (test)
2. **Task 2: VorliMessageContent + VorliCardPayload + Codable migration** - `b98a869` (feat)
3. **Task 3: emitCard + updateCardState + GREEN tests** - `628bb7b` (feat)

_Note: TDD plan — test commit followed by implementation commit per task_

## Files Created/Modified

- `Receipt Tracker/VorliService.swift` — Added VorliCardPayload, VorliMessageContent, updated VorliMessage with custom Codable and textContent property
- `Receipt Tracker/VorliChatViewModel.swift` — Updated streaming path to use textContent, added emitCard() and updateCardState() methods
- `Receipt Tracker/VorliChatView.swift` — Updated message rendering to use message.textContent instead of message.content
- `Receipt Tracker Tests/VorliMessageTests.swift` — Created with 4 green XCTest methods

## Decisions Made

- Backward-compat decode placed in VorliMessage.init(from:) rather than VorliMessageContent: old sessions had `"content": "string"` as a scalar value at the VorliMessage level; VorliMessageContent's keyed-container decoder cannot decode a scalar string directly
- Tests 3 and 4 (ViewModel-dependent) use `async` test methods: non-async `@MainActor` XCTest methods crash on simulator clones due to app launch denial (pre-existing simulator infrastructure issue); async methods avoid this
- VorliChatView.onChange(of:) uses `messages.last?.textContent` (String) rather than `.content` (VorliMessageContent): keeps scroll-trigger simple and avoids need to import VorliMessageContent into the view layer explicitly

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Backward-compat decode restructured from VorliMessageContent to VorliMessage level**
- **Found during:** Task 3 (testVorliMessageBackwardCompatDecode failed)
- **Issue:** Plan placed backward-compat decode logic inside VorliMessageContent.init(from:), but old JSON has `"content": "hello"` as a scalar String at the VorliMessage level — VorliMessageContent receives a keyed-container decoder which throws when the underlying value is a scalar, not a dict
- **Fix:** Added custom VorliMessage.init(from:) that first tries VorliMessageContent decode, then falls back to bare String decode on failure; simplified VorliMessageContent.init(from:) to only handle new discriminated format
- **Files modified:** Receipt Tracker/VorliService.swift
- **Verification:** testVorliMessageBackwardCompatDecode passes green
- **Committed in:** 628bb7b (Task 3 commit)

**2. [Rule 1 - Bug] VorliChatView.swift updated to use textContent**
- **Found during:** Task 2 (compile error from VorliMessage.content type change)
- **Issue:** VorliChatView.swift passed `message.content` (now VorliMessageContent, not String) to UserMessageBubble and AIResponseView which expect String
- **Fix:** Changed all view accesses to use `message.textContent`; also fixed streaming empty-check and onChange trigger
- **Files modified:** Receipt Tracker/VorliChatView.swift
- **Verification:** Build succeeds, tests pass
- **Committed in:** b98a869 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes required for correctness. Backward-compat structure is equivalent to plan intent — just applied at the right decode level.

## Issues Encountered

- VorliServiceTests (pre-existing from Phase 2) show 0.000s failure on simulator clones due to app launch permission denial (macOS/simulator infrastructure issue, not code). Not a regression from this plan — VorliServiceTests use non-async @MainActor methods which trigger the same simulator clone issue. Confirmed: VorliMessageTests resolve this by using async test methods for ViewModel-dependent tests.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- VorliMessage typed content model is complete and tested — ready for card UI rendering (Plan 02)
- emitCard() + updateCardState() lifecycle established — Plans 03+ can call these directly
- All four VorliMessageTests pass green; existing VorliContextBuilderTests, TimeWindowTests pass
- No blockers for proceeding to card UI implementation

---
*Phase: 03-action-item-card-infrastructure*
*Completed: 2026-03-13*
