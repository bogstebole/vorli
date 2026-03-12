---
phase: 02
slug: intelligent-context
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Apple native) |
| **Config file** | None — XCTest target added in Wave 0 via Xcode: File > New > Target > Unit Testing Bundle |
| **Quick run command** | `xcodebuild test -scheme "Receipt TrackerTests" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Receipt_TrackerTests/VorliContextBuilderTests` |
| **Full suite command** | `xcodebuild test -scheme "Receipt TrackerTests" -destination "platform=iOS Simulator,name=iPhone 16"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick command (VorliContextBuilderTests — pure logic, no network, no SwiftData)
- **After every plan wave:** Run full suite including TimeWindowTests and VorliServiceTests
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-T1 | 01 | 0 | CTX-03 | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliContextBuilderTests/testCiljeviBlock` | ❌ Wave 0 | ⬜ pending |
| 02-01-T2 | 01 | 0 | CTX-03 | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliContextBuilderTests/testExpiredGoalClampedToZero` | ❌ Wave 0 | ⬜ pending |
| 02-01-T3 | 01 | 0 | CTX-03 | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliContextBuilderTests/testFinansijeCreatedForGoalsOnly` | ❌ Wave 0 | ⬜ pending |
| 02-02-T1 | 02 | 0 | CTX-04 | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/TimeWindowTests/testAllCasesRoundTrip` | ❌ Wave 0 | ⬜ pending |
| 02-02-T2 | 02 | 0 | CTX-04 | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliServiceClassifyTests/testFallbackOnUnknownResponse` | ❌ Wave 0 | ⬜ pending |
| 02-03-T1 | 03 | 0 | CTX-05 | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliServiceTests/testSystemPromptContainsKategorizacija` | ❌ Wave 0 | ⬜ pending |
| 02-03-T2 | 03 | 0 | CTX-05 | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliServiceTests/testSystemPromptMerchantNames` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add "Receipt Tracker Tests" XCTest unit target in Xcode (File > New > Target > Unit Testing Bundle)
- [ ] `Receipt TrackerTests/VorliContextBuilderTests.swift` — stubs for CTX-03 (`ciljevi` block, `preostalo_meseci` clamping, `finansije` guard)
- [ ] `Receipt TrackerTests/TimeWindowTests.swift` — stubs for CTX-04 (`TimeWindow` enum round-trip, fallback behavior)
- [ ] `Receipt TrackerTests/VorliServiceTests.swift` — stubs for CTX-05 (system prompt `KATEGORIZACIJA` string assertions)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live Haiku classification call returns correct window | CTX-04 | Requires real API key + network | Ask "šta sam trošio prošlog meseca?" → verify response scoped to last month data |
| Vorli mentions savings goal progress unprompted | CTX-03 | LLM output is non-deterministic | Set a goal, ask a spending question, verify response references the goal |
| Category sum is correct for "hrana" query | CTX-05 | LLM reasoning on real data | Ask "koliko sam potrošio na hranu?" → manually verify sum against receipts |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
