# Receipt Tracker

## What This Is

A native iOS expense tracker for the Serbian market that scans fiscal receipt QR codes to capture item-level spending data. Users get full visibility into what they bought (not just where), track budgets, and get AI-powered financial insights through Vorli — a built-in chat assistant that understands their actual spending patterns.

## Core Value

Item-level receipt detail + AI insights + budget planning combined: the user knows exactly what they spent, what it means, and what to do about it.

## Requirements

### Validated

- ✓ QR scan → receipt import — existing (Serbian fiscal QR via `suf.purs.gov.rs`)
- ✓ Vorli AI chat (basic) — existing (streaming Claude API, chat UI)

### Active

**Vorli AI Improvement (current milestone)**

- [ ] Vorli correctly answers expense queries using rich context (budget, income, goals, time windows)
- [ ] Vorli infers expense categories from raw merchant/item names without pre-labeling
- [ ] Vorli generates PDF weekly/monthly report action items inside the chat
- [ ] Vorli creates shopping list action items based on previous month's spending patterns
- [ ] Shopping list includes price comparison across Serbian merchants (Maxi, Lidl, etc.) via web search
- [ ] Budget and monthly income data is included in Vorli context
- [ ] Vorli automatically selects the correct time window based on question intent

**Core App (upcoming milestones)**

- [ ] OCR scan for receipts without QR code
- [ ] Manual expense entry
- [ ] Full budget tracking (set, monitor, alert)
- [ ] Monthly income entry (50/30/20 or custom split)
- [ ] Wishlist / savings goal tracking with Vorli integration
- [ ] Proactive Vorli (background monitoring, month-start/end nudges)

### Out of Scope

- Multi-user / household sharing — single-user app for now
- Web/Android version — iOS only
- Connecting to bank APIs — manual receipt-based entry only
- Real-time price feeds — web search for shopping list comparison only (not live inventory)

## Context

- **Market**: Serbia — receipts from `suf.purs.gov.rs` fiscal system, amounts in RSD, Serbian language UI
- **Stack**: SwiftUI + SwiftData + Firebase Auth + Anthropic Claude API (SSE streaming)
- **AI model**: Claude via user-provided API key (personal use); future: subscription covers costs
- **Codebase state**: Core QR scanning and basic Vorli chat work. OCR parser exists (1134 lines) but not exposed. Manual entry, full budgeting, and wishlist are UI placeholders with TODOs.
- **Distribution**: Dog-fooding personally first, then App Store release targeting budget-conscious Serbian users

## Constraints

- **Platform**: iOS native only — SwiftUI, no cross-platform frameworks
- **Language**: Serbian UI, Serbian merchant/item names in receipt data
- **API costs**: User pays Anthropic directly via own key; keep calls efficient
- **Data locality**: All receipt data stays on-device (SwiftData); no backend server
- **Security**: API key currently in UserDefaults — should migrate to Keychain before public release

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Claude API with user-provided key | Avoids subscription infrastructure for personal use | — Pending |
| SwiftData (not Core Data) | Modern iOS persistence, simpler setup | ✓ Good |
| Serbian fiscal QR as primary input | Only reliable structured data source for Serbian receipts | ✓ Good |
| Item-level detail in Vorli context | Enables category inference without pre-labeling step | — Pending |

---
*Last updated: 2026-03-12 after initialization*
