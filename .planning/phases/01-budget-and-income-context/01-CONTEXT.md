# Phase 1: Budget and Income Context — Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend `VorliContextBuilder` to serialize live budget balance and income/savings data into every Vorli prompt. Update `VorliChatViewModel` to pass `Budget` snapshot to the context builder. The goal is that Vorli can correctly answer questions about remaining balance, affordability, and whether spending is on track with the user's savings split.

This phase does NOT include: manual expense entry, recurring expenses, bank XML import, or improvements to category inference (those are Phase 2+).

</domain>

<decisions>
## Implementation Decisions

### Budget model
- `Budget` is a wallet balance: starts with a manually entered amount, decremented each time a receipt is scanned
- `Budget.currentBalance` = remaining balance (e.g., 18,000 RSD)
- `Budget.lastUpdated` = when the balance was last set/topped up
- For Vorli context, include: `currentBalance` + `lastUpdated` — enough for "ostalo ti je X od Y koje si dodao [datum]" responses
- Do NOT include full `BudgetEntry` history in Phase 1 — current snapshot is sufficient

### Context structure
- Add a new top-level JSON key `finansije` to the context object (separate from `racuni_period` and `meta`)
- Structure: `{ "finansije": { "stanje": 18000.0, "poslednji_unos": "2026-03-01", "mesecni_prihod": 100000, "budzet_model": { "potrebe": 50, "zabava": 30, "stednja": 20 } } }`
- Labeled budget split — explicitly map "potrebe" (50%), "zabava" (30%), "stednja" (20%) so Vorli can evaluate spending against each category

### Income vs balance
- Monthly income (`mesecniPrihod`) currently lives in the system prompt — it should ALSO be in the JSON context so Vorli can do math (calculate 50% of income for "potrebe" target, etc.)
- "On track" = spending fits within the labeled 50/30/20 split — not just whether balance is positive
- Parse the budget model string (e.g., "50/20/30") into labeled JSON — `potrebe`, `zabava`, `stednja`

### ViewModel wiring
- Follow existing pattern: `VorliChatView` uses `@Query` for receipts and passes them to `VorliChatViewModel` init
- Same pattern for Budget: add `@Query var budgets: [Budget]` in `VorliChatView`, pass `budgets.first` to ViewModel init
- `VorliChatViewModel.init` signature extends to: `init(allReceipts: [Receipt], budget: Budget?)`
- Budget is optional — if nil (user hasn't set one), Vorli should handle gracefully without crashing

### Claude's Discretion
- Exact JSON field names for `finansije` (can use Serbian or English keys, consistent with existing context)
- How to handle nil budget (graceful fallback in context JSON — omit key or include with null values)
- Whether to update the system prompt to reference the new `finansije` JSON key

</decisions>

<specifics>
## Specific Ideas

- Vorli response for budget question: "Ostalo ti je 18,000 od 20,000 RSD koje si dodao 1. marta." — balance + date of last top-up
- Budget split should be labeled, not raw string — "potrebe: 50%, zabava: 30%, stednja: 20%"
- Bank XML import (auto-update balance from bank file) — noted as deferred, not for Phase 1

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VorliContextBuilder.build()` — extend with optional `budget: Budget?` parameter; add `finansije` key to the output dict
- `VorliUserProfile.load()` — already loads `mesecniPrihod` and `budzetModel` string; parse `budzetModel` into labeled struct here or in ContextBuilder
- `VorliChatViewModel.init(allReceipts:)` — extend to `init(allReceipts:budget:)`
- `VorliChatView` — already has `@Query var receipts: [Receipt]`; add `@Query var budgets: [Budget]`

### Established Patterns
- Context builder uses Serbian key names (`prodavnica`, `datum`, `ukupno_rsd`) — budget keys should follow same convention (`stanje`, `poslednji_unos`, `mesecni_prihod`)
- All `@Query` results passed to ViewModel in init — don't break this pattern
- `@MainActor` on `VorliChatViewModel` — budget data passed in will be on main actor

### Integration Points
- `VorliContextBuilder.build()` → add `finansije` section to output JSON dict
- `VorliChatViewModel.buildContext(for:)` → pass budget to `VorliContextBuilder.build()`
- `VorliChatView` → add `@Query var budgets: [Budget]` and pass `budgets.first` to ViewModel
- `Budget` model (`Receipt.swift`) — `currentBalance: Decimal`, `lastUpdated: Date` — both available

</code_context>

<deferred>
## Deferred Ideas

- Bank XML import — auto-update `Budget.currentBalance` by importing bank statement XML files. Interesting idea, separate phase.
- Manual expense entry — add expenses without scanning (TODO in AddNewSheet.swift). Separate phase.
- Recurring monthly expenses (car loan, apartment loan) — not trackable via QR scan. Separate phase.
- BudgetEntry history across months — once Phase 1 is done, richer history could be added in a later phase.

</deferred>

---

*Phase: 01-budget-and-income-context*
*Context gathered: 2026-03-12*
