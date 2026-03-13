# Roadmap: Receipt Tracker — Vorli AI Improvement

## Overview

This milestone transforms Vorli from a basic chat assistant into a context-aware financial advisor. Work progresses through three natural layers: first enriching Vorli's prompt context with real financial data (budget, income, goals, categories, time windows), then building the infrastructure to render action item cards inline in chat, then delivering the two concrete action items (PDF reports and shopping lists with Serbian merchant price comparisons).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Budget and Income Context** - Inject live budget and income data into every Vorli prompt (completed 2026-03-12)
- [x] **Phase 2: Intelligent Context** - Add savings goals, smart time windows, and category inference (completed 2026-03-13)
- [ ] **Phase 3: Action Item Card Infrastructure** - Build the card rendering system for inline chat actions
- [ ] **Phase 4: PDF Report Card** - Vorli generates a downloadable PDF report as an inline chat card
- [ ] **Phase 5: Shopping List Card** - Vorli creates a shopping list from spending patterns as an inline chat card
- [ ] **Phase 6: Price Comparison** - Shopping list includes price comparison across Serbian merchants via web search

## Phase Details

### Phase 1: Budget and Income Context
**Goal**: Vorli has access to the user's real financial picture — active budget entries, remaining budget balance, and monthly income with savings split — so answers about spending are grounded in actual financial capacity.
**Depends on**: Nothing (existing VorliContextBuilder extended)
**Requirements**: CTX-01, CTX-02
**Success Criteria** (what must be TRUE):
  1. When the user asks "koliko mi je ostalo od budzeta?" Vorli answers with the correct remaining budget amount pulled from SwiftData
  2. When the user asks about affordability, Vorli references their monthly income and savings split (e.g. 50/30/20) in the response
  3. Budget data and income data appear in the system prompt context block sent to the Anthropic API
  4. VorliContextBuilder serializes Budget + BudgetEntry records alongside receipts without breaking existing receipt context
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — Parse budzetModel string into BudzetModelJSON struct; extend VorliContextBuilder.build() with finansije JSON section
- [ ] 01-02-PLAN.md — Extend VorliChatViewModel init to accept Budget; wire @Query budgets through VorliChatView

### Phase 2: Intelligent Context
**Goal**: Vorli understands when "this month" vs "last month" vs a custom range is intended, correctly groups spending into categories without any manual labeling, and references the user's savings goals when relevant.
**Depends on**: Phase 1
**Requirements**: CTX-03, CTX-04, CTX-05
**Success Criteria** (what must be TRUE):
  1. Asking "sta sam trosio proslog meseca?" returns data scoped to last month without the user specifying a date range
  2. Asking "koliko sam potrosio na hranu?" returns a correct sum even though receipts use raw merchant/item names (no category tags in the database)
  3. When the user has a savings goal set, Vorli mentions progress toward it when relevant to the question asked
  4. Vorli does not require the user to say "this month" or "last month" — it infers the intent from natural language
**Plans**: 4 plans

Plans:
- [ ] 02-01-PLAN.md — Add XCTest bundle target (human action) and write RED test stubs for CTX-03, CTX-04, CTX-05
- [ ] 02-02-PLAN.md — SavingsGoal SwiftData model, ciljevi JSON context block, Settings UI, ViewModel/View wiring (CTX-03)
- [ ] 02-03-PLAN.md — KATEGORIZACIJA section in buildSystemPrompt() covering Serbian merchant chains (CTX-05)
- [ ] 02-04-PLAN.md — TimeWindow enum, classifyIntent() Haiku call, async send() refactor (CTX-04)

### Phase 3: Action Item Card Infrastructure
**Goal**: The chat UI can render structured action item cards inline alongside text messages — cards have a distinct visual treatment and expose a primary action (download, share, or view).
**Depends on**: Phase 2
**Requirements**: UX-01, UX-02
**Success Criteria** (what must be TRUE):
  1. A card component renders visibly distinct from a plain text message bubble in the chat scroll view
  2. Each card displays a title, a brief description, and a primary action button (e.g. "Preuzmi PDF" or "Pogledaj listu")
  3. Tapping the primary action button on a card triggers its action (download, share sheet, or preview) without crashing
  4. VorliChatViewModel can emit a message containing a card payload (not just a text string) and the View renders it correctly
  5. Cards with no action available (e.g. while generating) show a loading/disabled state
**Plans**: 2 plans

Plans:
- [ ] 03-01-PLAN.md — VorliMessage type extension (VorliCardPayload + VorliMessageContent enum) + Codable migration + ViewModel helpers, TDD green
- [ ] 03-02-PLAN.md — ActionItemCardView component (Figma-spec) + ChatMessagesView wiring + visual checkpoint

### Phase 4: PDF Report Card
**Goal**: When the user asks Vorli to generate a weekly or monthly report, a PDF report card appears inline in the chat — the user can preview the report and download or share it.
**Depends on**: Phase 3
**Requirements**: ACT-01
**Success Criteria** (what must be TRUE):
  1. Asking "napravi izvestaj za ovaj mesec" causes a PDF report card to appear inline in the Vorli chat (not a text summary)
  2. The PDF contains item-level spending broken down by category, total spend, and comparison to budget
  3. Tapping the download button on the card saves the PDF to the Files app or shares it via the iOS share sheet
  4. The report is generated entirely on-device using receipt data from SwiftData (no external API call for the PDF itself)
**Plans**: TBD

### Phase 5: Shopping List Card
**Goal**: When the user asks for a shopping list, Vorli generates one based on the previous month's actual spending patterns — the list appears as an inline card that distinguishes daily staples from bulk/biweekly purchases.
**Depends on**: Phase 3
**Requirements**: ACT-02, ACT-04
**Success Criteria** (what must be TRUE):
  1. Asking "napravi mi listu za kupovinu" produces a shopping list card inline in the chat
  2. The shopping list reflects items actually purchased in the previous month (not generic suggestions)
  3. The list visually separates daily purchase items (hleb, mleko) from biweekly/bulk items (deterdzent, ulje)
  4. The user can export or share the shopping list from the card's action button
**Plans**: TBD

### Phase 6: Price Comparison
**Goal**: Shopping list cards include per-item price comparisons across Serbian merchants (Maxi, Lidl, etc.) sourced via web search, so the user can see where to buy each item cheapest.
**Depends on**: Phase 5
**Requirements**: ACT-03
**Success Criteria** (what must be TRUE):
  1. A shopping list card displays price estimates for key items at two or more Serbian merchants (e.g. Maxi vs Lidl)
  2. Prices shown are sourced via a web search call at the time the list is generated (not hardcoded)
  3. When web search is unavailable or returns no results for an item, the card shows the item without a price rather than failing
  4. The user can see which merchant offers the lowest total basket price
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Budget and Income Context | 2/2 | Complete   | 2026-03-12 |
| 2. Intelligent Context | 4/4 | Complete   | 2026-03-13 |
| 3. Action Item Card Infrastructure | 0/TBD | Not started | - |
| 4. PDF Report Card | 0/TBD | Not started | - |
| 5. Shopping List Card | 0/TBD | Not started | - |
| 6. Price Comparison | 0/TBD | Not started | - |
