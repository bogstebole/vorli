---
phase: 03-action-item-card-infrastructure
plan: 02
subsystem: ui
tags: [swift, swiftui, vorli, card-ui, figma, checkpoint]

# Dependency graph
requires:
  - phase: 03-action-item-card-infrastructure
    plan: 01
    provides: VorliCardPayload, VorliMessageContent (.text/.card), VorliMessage.textContent

provides:
  - ActionItemCardView (top-level card component)
  - CardThumbnailView (stacked fanned mini-cards with shimmer)
  - CardActionButton (circular 28x28pt button with share sheet)
  - ShimmerModifier (ViewModifier for loading state)
  - Color(hex:) initializer extension
  - ChatMessagesView updated to switch on .text/.card — cards render inline in chat

affects:
  - 03-03: PDF generation (will update ActionItemCardView action button with real content)
  - 04+: Any phase emitting cards via emitCard() — rendered automatically by ChatMessagesView

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Figma-spec card layout: HStack thumbnail + VStack text rows + shadow stack
    - ShimmerModifier: animated LinearGradient phase offset for loading state
    - PBXFileSystemSynchronizedRootGroup: new Swift files auto-included without pbxproj edits
    - ShareLink stub: placeholder share target for Phase 3, real content in Phase 4/5

key-files:
  created:
    - Receipt Tracker/ActionItemCardView.swift
  modified:
    - Receipt Tracker/VorliChatView.swift

key-decisions:
  - "Color(hex:) added to ActionItemCardView.swift — not present in Extensions.swift so no duplicate"
  - "CardActionButton is a View struct (not a plain Button) so it can own @State showShareSheet for sheet presentation"
  - "HStack+Spacer(minLength:40) wrapper around ActionItemCardView mirrors AIResponseView container pattern to prevent card from bleeding to trailing screen edge"
  - "Pre-existing VorliServiceTests failures (0.000s on simulator clones) not a regression — documented in Plan 01 summary, caused by non-async @MainActor test methods on simulator clone infrastructure"

# Metrics
duration: 8min
completed: 2026-03-13
---

# Phase 3 Plan 02: ActionItemCardView Component Summary

**ActionItemCardView built to Figma spec with shimmer, fanned thumbnail, and share sheet — wired into ChatMessagesView switch on .text/.card content, completing Phase 3 card rendering infrastructure**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-13T13:10:01Z
- **Completed:** 2026-03-13T13:18:00Z (estimated, pre-checkpoint)
- **Tasks:** 2 of 3 complete (Task 3 is human-verify checkpoint)
- **Files modified:** 2

## Accomplishments

- `ActionItemCardView.swift` created with ShimmerModifier, CardThumbnailView, CardActionButton, ActionItemCardView
- Card matches Figma spec: LinearGradient background (#F2F1F1 to #FFFFFF), 18pt corner radius, five-layer shadow stack
- CardThumbnailView: three stacked fanned mini-cards at -8/-3/0 degrees with PDF (red text) and ShoppingList (cart icon) variants
- CardActionButton: 28x28pt circle with .tertiary fill, share sheet stub via ShareLink, dimmed when .loading/.disabled
- ShimmerModifier: animated phase-offset LinearGradient overlay, activated when actionState == .loading
- `VorliChatView.swift` ChatMessagesView updated: else branch now switches on `message.content` (.text → AIResponseView, .card → ActionItemCardView wrapped in HStack+Spacer)
- `#Preview` shows both card variants (PDF ready, ShoppingList loading) side by side
- All VorliMessageTests (4/4), VorliContextBuilderTests (3/3), TimeWindowTests (2/2) pass

## Task Commits

1. **Task 1: ActionItemCardView.swift** - `594859b` (feat)
2. **Task 2: VorliChatView.swift ChatMessagesView branching** - `f0dd2d1` (feat)
3. **Task 3: Visual verification** — awaiting human checkpoint

## Files Created/Modified

- `Receipt Tracker/ActionItemCardView.swift` — New file: ActionItemCardView, CardThumbnailView, CardActionButton, ShimmerModifier, Color(hex:)
- `Receipt Tracker/VorliChatView.swift` — Updated: ChatMessagesView else branch switched on message.content

## Decisions Made

- `Color(hex:)` added to ActionItemCardView.swift — Extensions.swift does not contain it, no duplicate risk
- `CardActionButton` implemented as a `View` struct (not inline Button) so it can hold `@State var showShareSheet` and attach `.sheet(isPresented:)` to the view's own lifecycle
- `HStack + Spacer(minLength: 40)` wrapper on ActionItemCardView in ChatMessagesView mirrors the container pattern used by AIResponseView — prevents card from bleeding to screen trailing edge
- ShareLink stub uses `URL("https://vorli.app")` as placeholder — Phase 4/5 will replace with generated PDF URL or shopping list content

## Deviations from Plan

None — plan executed exactly as written.

Plan noted that UserMessageBubble and streaming indicator already used `textContent` (fixed in Plan 01) and onChange(of:) already used `textContent`. Confirmed both are correct in current code — no changes needed for those items.

## Issues Encountered

- `VorliServiceTests` (2 tests) continue to fail on simulator clones — pre-existing infrastructure issue documented in Plan 01 summary. Not a regression from this plan.

## User Setup Required

None.

## Next Phase Readiness

- ActionItemCardView infrastructure complete — Phase 4 (PDF generation) can call `emitCard()` and the card will render automatically in chat
- Visual checkpoint (Task 3) must be approved before plan is marked complete
- No code blockers for proceeding to Phase 3 Plan 03 (PDF generation)

---
*Phase: 03-action-item-card-infrastructure*
*Completed: 2026-03-13 (pending visual checkpoint)*

## Self-Check: PASSED

- FOUND: Receipt Tracker/ActionItemCardView.swift (ActionItemCardView, CardThumbnailView, CardActionButton, ShimmerModifier, Color(hex:))
- FOUND: Receipt Tracker/VorliChatView.swift (case .card(let payload): ActionItemCardView)
- FOUND commit 594859b (feat: ActionItemCardView)
- FOUND commit f0dd2d1 (feat: ChatMessagesView branching)
