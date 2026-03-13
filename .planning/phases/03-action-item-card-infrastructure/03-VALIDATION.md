---
phase: 3
slug: action-item-card-infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing target: "Receipt Tracker Tests") |
| **Config file** | Receipt Tracker Tests/ target in Xcode project |
| **Quick run command** | `xcodebuild test -scheme "Receipt Tracker" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"Receipt Tracker Tests/VorliMessageTests" 2>&1 \| grep -E "(Test Suite|PASS|FAIL|error:)"` |
| **Full suite command** | `xcodebuild test -scheme "Receipt Tracker" -destination "platform=iOS Simulator,name=iPhone 16" 2>&1 \| tail -20` |
| **Estimated runtime** | ~15 seconds (quick), ~60 seconds (full) |

---

## Sampling Rate

- **After every task commit:** Run quick command (VorliMessageTests only, ~15s)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 3-W0-01 | 01 | 0 | UX-01, UX-02 | unit stubs | quick run | ❌ Wave 0 | ⬜ pending |
| 3-01-01 | 01 | 1 | UX-01 | unit | quick run | ❌ Wave 0 | ⬜ pending |
| 3-01-02 | 01 | 1 | UX-01 | unit | quick run | ❌ Wave 0 | ⬜ pending |
| 3-01-03 | 01 | 1 | UX-01 | unit | quick run | ❌ Wave 0 | ⬜ pending |
| 3-02-01 | 02 | 2 | UX-02 | unit | quick run | ❌ Wave 0 | ⬜ pending |
| 3-03-01 | 03 | 2 | UX-01 | manual | — | N/A | ⬜ pending |
| 3-03-02 | 03 | 2 | UX-01 | manual | — | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Receipt Tracker Tests/VorliMessageTests.swift` — stubs covering:
  - `VorliMessage` with `.card` content Codable roundtrip (UX-01)
  - `VorliMessage` old bare-string backward-compat decode (UX-01)
  - `VorliChatViewModel.emitCard()` appends `.card` message (UX-01)
  - `VorliChatViewModel.updateCardState()` transitions actionState (UX-02)

*No framework install needed — XCTest target already exists in the project.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Card renders visibly distinct from text bubble in chat scroll view | UX-01 | Visual layout cannot be asserted in XCTest | Run app on simulator, ask Vorli a question that triggers a card, verify card has distinct background and thumbnail |
| Tapping action button triggers share sheet without crashing | UX-02 | UI interaction + system sheet requires Simulator | Tap card action button, verify iOS share sheet appears and no crash occurs |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
