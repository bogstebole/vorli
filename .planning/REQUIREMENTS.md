# Requirements: Receipt Tracker — Vorli AI Improvement

**Defined:** 2026-03-12
**Core Value:** Item-level receipt detail + AI insights + budget planning: know exactly what you spent, what it means, and what to do about it.

## v1 Requirements

### Context Engine

- [x] **CTX-01**: Vorli receives budget entries and remaining budget in context
- [x] **CTX-02**: Vorli receives monthly income and savings split (e.g. 50/30/20) in context
- [x] **CTX-03**: Vorli receives savings goals in context
- [x] **CTX-04**: Vorli automatically selects the correct time window based on question intent (this month, last month, custom range)
- [x] **CTX-05**: Vorli infers expense categories from raw merchant and item names without pre-labeling

### Action Items in Chat

- [ ] **ACT-01**: Vorli generates a PDF weekly/monthly report — card appears inline in chat, user can preview and download
- [ ] **ACT-02**: Vorli creates a shopping list based on previous month's spending patterns — card appears inline in chat
- [ ] **ACT-03**: Shopping list includes price comparison across Serbian merchants (Maxi, Lidl, etc.) via web search
- [ ] **ACT-04**: Shopping list distinguishes items to buy daily vs. biweekly/bulk purchases

### Chat UX

- [ ] **UX-01**: Chat displays action item cards inline (PDF report card, shopping list card) — not just text
- [ ] **UX-02**: Action item cards have a download/share action (PDF export, list export)

## v2 Requirements

### Proactive Vorli

- **PRO-01**: Vorli monitors spending in the background and surfaces alerts only when needed
- **PRO-02**: Vorli sends month-start nudge (budget plan for the month)
- **PRO-03**: Vorli sends month-end summary (how did you do vs. goals)
- **PRO-04**: Vorli warns when approaching budget limits mid-month

### Wishlist & Savings Goals

- **WISH-01**: Dedicated wishlist section in the app for savings targets
- **WISH-02**: Vorli tracks wishlist items and calculates monthly savings needed
- **WISH-03**: Vorli proactively reports progress on savings goals at month-end

### Expanded Scanning

- **SCAN-01**: OCR scan for receipts without QR code
- **SCAN-02**: Manual expense entry

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-user / household sharing | Single-user app for now |
| Web/Android version | iOS only |
| Bank API integration | Receipt-based entry only, no bank connections |
| Real-time price feeds | Web search for shopping list only, not live inventory |
| Category pre-labeling | AI infers categories from raw data — no manual tagging needed |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CTX-01 | Phase 1 | Complete |
| CTX-02 | Phase 1 | Complete |
| CTX-03 | Phase 2 | Complete |
| CTX-04 | Phase 2 | Complete |
| CTX-05 | Phase 2 | Complete |
| ACT-01 | Phase 4 | Pending |
| ACT-02 | Phase 5 | Pending |
| ACT-03 | Phase 6 | Pending |
| ACT-04 | Phase 5 | Pending |
| UX-01 | Phase 3 | Pending |
| UX-02 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-12*
*Last updated: 2026-03-12 — traceability filled after roadmap creation*
