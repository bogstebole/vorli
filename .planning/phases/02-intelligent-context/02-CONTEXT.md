# Phase 2: Intelligent Context — Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend Vorli's context pipeline so that:
1. Time window is inferred on-device from free-text questions (using a Haiku classification call), not manually selected by the user
2. Savings goals are stored as a structured SwiftData model (`SavingsGoal`) and injected into Vorli's JSON context
3. Category inference is improved via an expanded `KATEGORIZACIJA` section in the system prompt covering major Serbian merchant chains

This phase does NOT include: UI for managing goals beyond settings entry, price comparison, action item cards, or the wishlist roadmap feature (WISH-01).

</domain>

<decisions>
## Implementation Decisions

### Time window inference
- On-device: Haiku API call classifies question intent → returns a time window enum before the main Sonnet call
- 5 time windows: `this_month`, `last_month`, `this_week`, `last_week`, `recent` (6 months catch-all)
- `buildContext(for:)` in `VorliChatViewModel` routes based on the classified window — same as how quick prompts currently hardcode the window
- Pattern: classify intent → filter receipts → build context → main Sonnet call
- Quick prompts (REPORT_MONTH, REPORT_WEEK) bypass classification — they already know the window

### Savings goals data model
- New `SavingsGoal` SwiftData model: `naziv: String`, `ciljniIznos: Decimal`, `rok: Date`
- Up to 3 active goals simultaneously
- Queried via `@Query var savingsGoals: [SavingsGoal]` in `VorliChatView`, passed to `VorliChatViewModel` init (same pattern as `Budget`)
- JSON context block `ciljevi` added to `finansije` section: array of `{ naziv, cilj_rsd, rok, preostalo_meseci }`
- `preostalo_meseci` computed from `rok - today` at context build time
- Settings UI: existing `aktivniCilj` text field replaced by structured form (3 fields: name, amount, deadline) for up to 3 goals

### Category inference
- Extend `buildSystemPrompt()` in `VorliService` with a `KATEGORIZACIJA` section
- Section covers major Serbian merchant chains by category:
  - **Namirnice**: Maxi, Lidl, Roda, Idea, DP, Univerexport, Mercator, Tempo
  - **Apoteke / kozmetika**: DM, Lilly, Biljka
  - **Gorivo**: NIS, NIS Petrol, OMV, MOL, Lukoil, Gazprom, Enis (item names already covered by existing prompt section)
  - **Brza hrana**: McDonald's, KFC, Burger King, Pizza Hut
- Instruction: Claude must infer category from BOTH merchant name AND item names — never return "N/A" for a category question

### Claude's Discretion
- Exact Haiku prompt for intent classification (keep it minimal — just return enum value)
- How to handle classification API errors (fall back to `recent` window silently)
- Exact JSON field names in `ciljevi` array
- How to handle expired goal deadlines (include or exclude from context)
- SettingsSheet UI layout for 3-goal entry form

</decisions>

<specifics>
## Specific Ideas

- `preostalo_meseci` in the goal context lets Vorli say "do cilja ti nedostaje X RSD, a imate još Y meseci" — concrete progress framing
- Classification call should be minimal: send just the question text, return one of 5 enum values. No receipt data, no history.
- The existing `PRETRAGA` case in `buildContext()` (sends 6 months) becomes the fallback for `recent` window — no change needed there

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VorliChatViewModel.buildContext(for:)` — extend with a new async classification step before the switch; add `this_month`, `last_month`, `this_week`, `last_week` branches using existing `VorliContextBuilder` helpers
- `VorliContextBuilder.receiptsForCurrentMonth/PreviousMonth/CurrentWeek/PreviousWeek()` — already implemented, just need to be wired to classified intent
- `VorliService.buildSystemPrompt()` — extend with `KATEGORIZACIJA` section
- `VorliChatView` — already has `@Query var receipts` and `@Query var budgets`; add `@Query var savingsGoals: [SavingsGoal]`
- `VorliChatViewModel.init(allReceipts:budget:)` — extend to `init(allReceipts:budget:savingsGoals:)`

### Established Patterns
- Serbian key names in JSON context (`stanje`, `poslednji_unos`) — goal keys follow same convention (`naziv`, `cilj_rsd`, `rok`, `preostalo_meseci`)
- `@Query` results passed to ViewModel in init — don't break this pattern
- `VorliUserProfile.aktivniCilj` currently in system prompt — migrate to JSON context once `SavingsGoal` model exists

### Integration Points
- `VorliContextBuilder.build()` → add `ciljevi` array inside `finansije` block (alongside existing `stanje`, `mesecni_prihod`, `budzet_model`)
- `VorliChatViewModel.send()` → make async (or use Task wrapper) to await Haiku classification before building context
- `SettingsSheet.swift` → replace aktivniCilj text field with structured goal entry UI
- `Receipt.swift` → add `SavingsGoal` SwiftData model

</code_context>

<deferred>
## Deferred Ideas

- Multiple goals UI beyond settings (dedicated Wishlist screen) — this is WISH-01 on the roadmap, a separate phase
- Goal progress visualization (chart, progress bar in app) — UI feature, separate phase
- Proactive goal nudges (month-end summary with goal progress) — PRO-03 on the roadmap
- Custom date range time windows (e.g., "od 1. do 15. marta") — complex date parsing, low frequency use case

</deferred>

---

*Phase: 02-intelligent-context*
*Context gathered: 2026-03-12*
