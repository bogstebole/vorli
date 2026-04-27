# Phase 02: Intelligent Context — Research

**Researched:** 2026-03-12
**Domain:** SwiftData model extension, async intent classification via Anthropic API, system prompt engineering
**Confidence:** HIGH

## Summary

Phase 2 extends an already-working pipeline in three distinct directions: (1) a new `SavingsGoal` SwiftData model injected into context, (2) an upstream Haiku classification call in `send()` that selects the right time-window before the main Sonnet call, and (3) an expanded `KATEGORIZACIJA` section in `buildSystemPrompt()` covering Serbian merchant chains. All three are additive — nothing in Phase 1 needs to be reverted or restructured.

The key structural change is making `VorliChatViewModel.send()` async-aware. Currently `send()` is a synchronous function that launches a detached `Task` internally (inside `VorliService.sendMessage()`). Adding a Haiku pre-call means `send()` itself must `await` before calling the service. The cleanest approach is wrapping the whole `send()` body in a new `Task` block on `@MainActor`, identical to the pattern `VorliService` already uses.

SwiftData migration is the one real risk: the app has no `VersionedSchema` or migration plan. Adding `SavingsGoal` with non-optional fields will crash on upgrade from a schema that doesn't include it unless optional initializers or lightweight migration are used. The safe pattern is giving every `SavingsGoal` property an optional type or a default value.

**Primary recommendation:** Implement in three isolated waves — `SavingsGoal` model + wiring first, then intent classification, then `KATEGORIZACIJA` string extension. Each wave is independently testable and deployable.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Time window inference: Haiku API call classifies question intent, returns one of 5 windows (`this_month`, `last_month`, `this_week`, `last_week`, `recent`). `buildContext(for:)` routes based on classified window.
- Quick prompts (`REPORT_MONTH`, `REPORT_WEEK`) bypass classification — they already know the window.
- New `SavingsGoal` SwiftData model: `naziv: String`, `ciljniIznos: Decimal`, `rok: Date`. Up to 3 active goals.
- `@Query var savingsGoals: [SavingsGoal]` in `VorliChatView`, passed to `VorliChatViewModel` init (same pattern as `Budget`).
- JSON context block `ciljevi` added inside `finansije` section: array of `{ naziv, cilj_rsd, rok, preostalo_meseci }`.
- `preostalo_meseci` computed from `rok - today` at context build time.
- Settings UI: existing `aktivniCilj` text field replaced by structured form (3 fields: name, amount, deadline) for up to 3 goals.
- `KATEGORIZACIJA` section added to `buildSystemPrompt()` covering named Serbian merchant chains by category.

### Claude's Discretion
- Exact Haiku prompt for intent classification (keep it minimal — just return enum value)
- How to handle classification API errors (fall back to `recent` window silently)
- Exact JSON field names in `ciljevi` array
- How to handle expired goal deadlines (include or exclude from context)
- SettingsSheet UI layout for 3-goal entry form

### Deferred Ideas (OUT OF SCOPE)
- Multiple goals UI beyond settings (dedicated Wishlist screen) — WISH-01 on the roadmap
- Goal progress visualization (chart, progress bar in app)
- Proactive goal nudges (month-end summary with goal progress) — PRO-03
- Custom date range time windows — complex date parsing, low frequency use case
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CTX-03 | Vorli receives savings goals in context | SavingsGoal SwiftData model + `ciljevi` JSON block in `finansije` section of VorliContextBuilder |
| CTX-04 | Vorli automatically selects the correct time window based on question intent | Haiku pre-classification call → routes to existing `receiptsForCurrentMonth/PreviousMonth/CurrentWeek/PreviousWeek()` helpers |
| CTX-05 | Vorli infers expense categories from raw merchant and item names without pre-labeling | Extended `KATEGORIZACIJA` section in `buildSystemPrompt()` with Serbian merchant chains |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ (current) | Persistent model for `SavingsGoal` | Already used for `Receipt`, `Budget`, `BudgetEntry` — zero new dependencies |
| Anthropic Messages API | 2023-06-01 (header) | Haiku intent classification + Sonnet main call | Already integrated via `VorliService`; reuse same `URLSession` pattern |
| Foundation | System | `Calendar`, `DateComponents`, `Decimal` arithmetic | Already used throughout |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `claude-haiku-4-20250514` (or latest Haiku) | Current | Cheap, fast classification | Pre-call only — not for the main conversational response |
| SwiftUI `Form` / `List` + `DatePicker` | iOS 17+ | Settings UI for structured goal entry | Replace `TextField` with typed fields (Text + `Decimal` + `Date`) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Haiku API classification | On-device NLP (e.g., NaturalLanguage.framework) | NL framework cannot map Serbian free-text to time window reliably; Haiku is 2–3 orders of magnitude more capable for this task |
| SwiftData `SavingsGoal` | UserDefaults struct | UserDefaults is already used for `VorliUserProfile`; structured goals with `Decimal` and `Date` warrant a proper model with SwiftData querying |

**Installation:** No new packages. All tools are already in the project.

---

## Architecture Patterns

### Recommended Structure for This Phase

```
VorliService.swift
├── classifyIntent(question:) async -> TimeWindow   ← new
└── sendMessage(...) streaming                       ← unchanged

VorliChatViewModel.swift
├── send(_ text:, requestType:)                      ← wraps async work in Task
│   ├── if requestType == "PRETRAGA": await classifyIntent → TimeWindow
│   └── buildContext(for: timeWindow.rawValue)
└── buildContext(for:)                               ← adds this_month/last_month/this_week/last_week branches

VorliContextBuilder.swift
└── build(... savingsGoals:)                         ← adds `ciljevi` to `finansije` block

Receipt.swift
└── SavingsGoal @Model                               ← new SwiftData model

VorliChatView.swift
└── @Query var savingsGoals: [SavingsGoal]          ← new query, passed to ViewModel init

SettingsSheet.swift
└── Section "Ciljevi štednje"                        ← replaces aktivniCilj TextField
```

### Pattern 1: Haiku Intent Classification

**What:** A minimal, non-streaming POST to `/v1/messages` using `claude-haiku-4-20250514` (or `claude-haiku-4-5`) that returns exactly one of the 5 enum values as a JSON-parseable word.

**When to use:** Only for free-text `send()` calls — quick prompts bypass it.

**Recommended prompt structure (Claude's discretion to finalize):**

```swift
// Source: existing VorliService pattern — same URLSession, no streaming
private func classifyIntent(question: String) async -> TimeWindow {
    let systemPrompt = """
    Klasifikuj vremenski period koji korisnik traži u JEDNOJ od sledećih vrednosti:
    this_month | last_month | this_week | last_week | recent
    Odgovori SAMO jednom od tih vrednosti — bez objašnjenja.
    """
    // Build minimal AnthropicRequest(model: haikuModel, max_tokens: 10, stream: false)
    // Parse response.content[0].text — strip whitespace, match to TimeWindow enum
    // On any error or unrecognized value: return .recent (silent fallback)
}
```

Key details:
- `max_tokens: 10` — enough for the longest enum value (`this_month` = 10 chars)
- `stream: false` — classification is synchronous, not streamed
- The system prompt sends only the question — no receipt data, no history (keeps cost minimal)
- A non-streaming response returns `{"content": [{"type": "text", "text": "this_month"}]}`

**Non-streaming response model (new private structs needed in VorliService):**

```swift
private struct AnthropicSyncResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}
```

### Pattern 2: Making `send()` Async-Safe

**What:** `send()` is currently `@MainActor` and synchronous. Adding `await classifyIntent()` requires the body to run in an async context.

**Current pattern (inside `VorliService.sendMessage`):**
```swift
Task {
    let (asyncBytes, response) = try await URLSession.shared.bytes(for: urlRequest)
    // ...
    await MainActor.run { onComplete() }
}
```

**New pattern for `send()` in `VorliChatViewModel`:**
```swift
func send(_ text: String, requestType: String = "PRETRAGA") {
    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    guard !isStreaming else { return }

    let userMsg = VorliMessage(role: .user, content: text)
    messages.append(userMsg)
    // set title...

    isStreaming = true
    let history = Array(messages.dropLast())

    Task { @MainActor in
        let window: TimeWindow
        if requestType == "PRETRAGA" {
            window = await service.classifyIntent(question: text)
        } else {
            window = TimeWindow(rawValue: requestType) ?? .recent
        }
        let context = buildContext(for: window.rawValue)
        // append empty assistant message
        // call service.sendMessage(...)
    }
}
```

This is the `@MainActor Task { }` idiom — the Task inherits the actor from the enclosing context, so all mutations to `@Observable` state remain on the main thread without `await MainActor.run { }` boilerplate.

### Pattern 3: SavingsGoal SwiftData Model

**What:** A new `@Model` class in `Receipt.swift` (or a new file).

```swift
@Model
final class SavingsGoal {
    var naziv: String
    var ciljniIznos: Decimal
    var rok: Date

    init(naziv: String = "", ciljniIznos: Decimal = 0, rok: Date = Date()) {
        self.naziv = naziv
        self.ciljniIznos = ciljniIznos
        self.rok = rok
    }
}
```

**Migration concern:** The app has NO `VersionedSchema` or `migrationPlan`. SwiftData's default behavior on a schema change is to **delete and recreate the store** in debug builds, and to **crash on upgrade** in production if the store already exists with the old schema. Safe mitigation: all `SavingsGoal` properties have default values in the `init`, which allows lightweight/automatic migration. The `ModelContainer` schema in `Receipt_TrackerApp.swift` must include `SavingsGoal.self`.

### Pattern 4: ciljevi JSON Block

**What:** `VorliContextBuilder.build()` gains a `savingsGoals: [SavingsGoal] = []` parameter. When non-empty, a `ciljevi` array is added inside the existing `finansije` dict.

```swift
// Inside VorliContextBuilder.build()
if !savingsGoals.isEmpty {
    let today = Date()
    let calendar = Calendar.current
    let goalMaps: [[String: Any]] = savingsGoals.map { goal in
        let months = calendar.dateComponents([.month], from: today, to: goal.rok).month ?? 0
        return [
            "naziv": goal.naziv,
            "cilj_rsd": Double(truncating: goal.ciljniIznos as NSDecimalNumber),
            "rok": dateFormatter.string(from: goal.rok),
            "preostalo_meseci": max(0, months)  // clamp to 0 for expired goals
        ]
    }
    finansijeDict["ciljevi"] = goalMaps
}
```

**Claude's discretion call — expired goals:** Clamp `preostalo_meseci` to `0` rather than excluding the goal. This lets Vorli say "rok je prošao" which is useful information.

### Pattern 5: TimeWindow Enum

**What:** A Swift enum that bridges the string-based `requestType` parameter to typed routing.

```swift
enum TimeWindow: String, CaseIterable {
    case thisMonth  = "this_month"
    case lastMonth  = "last_month"
    case thisWeek   = "this_week"
    case lastWeek   = "last_week"
    case recent     = "recent"
}
```

This replaces the stringly-typed `switch requestType` in `buildContext(for:)` with `switch window`.

### Pattern 6: KATEGORIZACIJA System Prompt Section

**What:** A multiline string appended to `buildSystemPrompt()` in `VorliService`. No API change, no model change.

```swift
private func buildSystemPrompt(userProfile: VorliUserProfile) -> String {
    """
    ... (existing content) ...

    === KATEGORIZACIJA ===
    Kada korisnik pita za kategoriju troška, zaključi kategoriju na osnovu NAZIVA PRODAVNICE i NAZIVA STAVKI.
    NIKAD ne vrati "N/A" za kategoriju — uvek zaključi na osnovu dostupnih podataka.

    Poznate prodavnice po kategorijama:
    - Namirnice: Maxi, Lidl, Roda, Idea, DP, Univerexport, Mercator, Tempo
    - Apoteke / kozmetika: DM, Lilly, Biljka
    - Gorivo: NIS, NIS Petrol, OMV, MOL, Lukoil, Gazprom, Enis
    - Brza hrana: McDonald's, KFC, Burger King, Pizza Hut

    Za ostale prodavnice, zaključi kategoriju iz naziva stavki (npr. "HLEB", "MLEKO" → namirnice).
    """
}
```

### Anti-Patterns to Avoid

- **Sending receipt data in the classification call:** The classification prompt must contain only the question text. Adding receipts inflates cost and latency for a call that only needs to return one of 5 words.
- **Making `send()` itself `async`:** If `send()` becomes `async func`, callers in the View (`viewModel?.send(text)`) need `Task { await viewModel?.send(text) }`. The `Task { @MainActor in }` wrapper inside `send()` avoids changing the call site.
- **Calling `classifyIntent()` for quick prompts:** Quick prompts already know their window. Skipping classification for `requestType != "PRETRAGA"` is both correct and cost-saving.
- **Non-optional SwiftData fields without defaults:** If `SavingsGoal` has non-optional fields with no init defaults, adding it to an existing container without a migration plan will crash on first launch after upgrade.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| NL intent detection | Custom keyword matcher for "prošli mesec" | Haiku classification call | Edge cases: "prethodnog meseca", "u oktobru", colloquial variants — LLM handles all of them |
| Month arithmetic | Manual date math for `preostalo_meseci` | `Calendar.dateComponents([.month], from:to:)` | Handles year boundaries, DST, partial months correctly |
| JSON serialization of `Decimal` | `String(describing: decimal)` | `Double(truncating: decimal as NSDecimalNumber)` | Already the established pattern in `VorliContextBuilder` — consistent with `budget.currentBalance` serialization |
| SwiftData schema migration | Custom migration handler | Default values on all `SavingsGoal` init params | Zero-config lightweight migration for additive schema changes |

**Key insight:** The most expensive hand-roll here would be keyword-based time window detection. Serbian has rich morphology ("prošli mesec", "prošlog meseca", "minulog meseca", "u oktobru") — a regex or keyword list will miss cases that a sub-cent Haiku call handles trivially.

---

## Common Pitfalls

### Pitfall 1: SwiftData crash on schema upgrade
**What goes wrong:** App launches on a device that has existing data, the schema now includes `SavingsGoal`, and SwiftData cannot automatically migrate because properties lack defaults.
**Why it happens:** SwiftData lightweight migration requires that new properties have default values or be optional. Without them, the migration fails silently in debug (store deleted) or fatally in release.
**How to avoid:** All `SavingsGoal` properties must have defaults in `init`. Add `SavingsGoal.self` to the `Schema(...)` array in `Receipt_TrackerApp.swift`.
**Warning signs:** `fatalError("Could not create ModelContainer")` in `Receipt_TrackerApp.swift` during testing on a device that already had the app installed.

### Pitfall 2: `send()` called while classification is in-flight
**What goes wrong:** User taps send twice rapidly. Second call passes `guard !isStreaming` but classification from first call hasn't returned yet — two concurrent Haiku calls and two concurrent Sonnet calls begin.
**Why it happens:** `isStreaming = true` is set after the `await`, not before it.
**How to avoid:** Set `isStreaming = true` immediately before entering the `Task` block (before the `await`), not after classification returns.

### Pitfall 3: Haiku model identifier drift
**What goes wrong:** `claude-haiku-4-20250514` gets deprecated; classification calls start returning 404 or use a more expensive model.
**Why it happens:** Hardcoded model strings in `VorliService`.
**How to avoid:** Define a `private let classificationModel = "claude-haiku-4-20250514"` constant separate from `private let model = "claude-sonnet-4-20250514"`. When the model changes, one string updates.

### Pitfall 4: `ciljevi` added to `finansije` when `finansije` block is absent
**What goes wrong:** `VorliContextBuilder.build()` only creates the `finansije` dict when `budget != nil || mesecniPrihod > 0`. If neither is set but goals exist, `ciljevi` is silently dropped.
**Why it happens:** The condition guards the entire block, not individual sub-keys.
**How to avoid:** Extend the condition: `if budget != nil || (userProfile?.mesecniPrihod ?? 0) > 0 || !savingsGoals.isEmpty`.

### Pitfall 5: `aktivniCilj` still in system prompt after migration
**What goes wrong:** Vorli references both the old `aktivniCilj` text (from system prompt) and the new `ciljevi` array (from context JSON) — duplicate, inconsistent goal information.
**Why it happens:** `buildSystemPrompt()` still includes the `aktivniCilj` line from `VorliUserProfile`.
**How to avoid:** In the same plan that adds `ciljevi` to context, remove the `aktivniCilj` line from `buildSystemPrompt()`. The CONTEXT.md explicitly calls this out: "migrate to JSON context once `SavingsGoal` model exists."

### Pitfall 6: `@Query` in VorliChatView not updating ViewModel
**What goes wrong:** User adds a goal in Settings, returns to chat, but ViewModel has stale `savingsGoals = []` because it was initialized with the old query result.
**Why it happens:** The ViewModel is created once in `.task {}` — it holds a value-type copy of `savingsGoals` from init time.
**How to avoid:** Follow the same pattern used for `budget: budgets.first` — the ViewModel is reconstructed (or `savingsGoals` property updated) when the `@Query` result changes. The simplest safe pattern: pass `savingsGoals` as a parameter to `buildContext()` at call time (from the View), not store it at init time. Alternatively, use the same `.task(id: savingsGoals.count)` re-init pattern.

---

## Code Examples

Verified patterns from existing codebase:

### Non-streaming Anthropic call (new pattern for classification)
```swift
// Adapts existing AnthropicRequest — set stream: false
private struct AnthropicSyncResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

// Call: URLSession.data(for:) instead of URLSession.bytes(for:)
let (data, response) = try await URLSession.shared.data(for: urlRequest)
let parsed = try JSONDecoder().decode(AnthropicSyncResponse.self, from: data)
let raw = parsed.content.first(where: { $0.type == "text" })?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "recent"
return TimeWindow(rawValue: raw) ?? .recent
```

### Decimal → Double in JSON (established pattern)
```swift
// Source: VorliContextBuilder.swift — existing pattern for Decimal fields
finansijeDict["cilj_rsd"] = Double(truncating: goal.ciljniIznos as NSDecimalNumber)
```

### Calendar month difference (safe date math)
```swift
// Source: Foundation Calendar API
let months = Calendar.current.dateComponents([.month], from: Date(), to: goal.rok).month ?? 0
let preostaloMeseci = max(0, months)
```

### Extending ViewModel init (established pattern from Phase 1)
```swift
// Before (Phase 1 result):
init(allReceipts: [Receipt], budget: Budget? = nil)

// After (Phase 2):
init(allReceipts: [Receipt], budget: Budget? = nil, savingsGoals: [SavingsGoal] = [])
```

### VorliChatView query + wiring (established @Query pattern)
```swift
// Add alongside existing @Query private var budgets: [Budget]
@Query private var savingsGoals: [SavingsGoal]

// In .task { }:
viewModel = VorliChatViewModel(
    allReceipts: allReceipts,
    budget: budgets.first,
    savingsGoals: savingsGoals
)
```

### SettingsSheet goal section pattern
```swift
// Replace aktivniCilj TextField with:
Section {
    ForEach(0..<3, id: \.self) { i in
        if i < goals.count {
            // Show existing goal with TextField (naziv), TextField (ciljniIznos), DatePicker (rok)
        } else {
            Button("Dodaj cilj") { /* append new SavingsGoal to modelContext */ }
        }
    }
} header: {
    Text("Ciljevi štednje")
        .font(.system(.caption, design: .monospaced))
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `aktivniCilj` free text in system prompt | Structured `SavingsGoal` model with `ciljevi` JSON array | Phase 2 | Enables Vorli to reference specific amounts, deadlines, and computed time remaining |
| Hardcoded `requestType` string switch | `TimeWindow` enum with Haiku classification | Phase 2 | Natural language question → correct data window automatically |
| No category guidance for non-fuel merchants | Expanded `KATEGORIZACIJA` section | Phase 2 | Prevents "N/A" responses on grocery/pharmacy/fast food questions |

**Deprecated/outdated after this phase:**
- `VorliUserProfile.aktivniCilj`: The field stays in the struct (used for Settings persistence migration) but its injection into the system prompt is removed.
- `requestType: String = "PRETRAGA"` as the only free-text branch: replaced by `TimeWindow.recent` as the fallback case.

---

## Open Questions

1. **Haiku model ID to use**
   - What we know: Current Sonnet is `claude-sonnet-4-20250514`. Haiku equivalent follows the same naming pattern.
   - What's unclear: Whether `claude-haiku-4-20250514` is the correct ID or if there is a newer slug (e.g., `claude-haiku-4-5`).
   - Recommendation: Use `claude-haiku-4-20250514` as the initial constant; if the API returns 404, check the Anthropic models list endpoint (`GET /v1/models`) at runtime. Plan should include the model constant as a named variable so it's a one-line change.

2. **SettingsSheet: @Environment(\.modelContext) vs passing goals via binding**
   - What we know: SettingsSheet currently uses only `UserDefaults` (no SwiftData). Adding goal CRUD requires a `modelContext`.
   - What's unclear: Whether SettingsSheet should receive `modelContext` via `@Environment` (standard SwiftData pattern) or be passed a binding to a goals array.
   - Recommendation: Use `@Environment(\.modelContext)` — it's the standard SwiftData write pattern in SwiftUI. The planner should note that the `modelContainer` is already provided at the app root so `@Environment(\.modelContext)` will work.

3. **savingsGoals stale-on-return problem**
   - What we know: The ViewModel is initialized once in `.task {}`. `@Query` results update reactively but the ViewModel holds a value copy from init time.
   - What's unclear: Whether `.task(id: savingsGoals.hashValue)` re-init is safe without losing chat session state.
   - Recommendation: Pass `savingsGoals` from the View into `buildContext()` at send time (not at init time). This keeps the ViewModel init unchanged and sidesteps the stale-copy problem entirely. The planner should pick this approach.

---

## Validation Architecture

`nyquist_validation` is `true` in `.planning/config.json`. No XCTest target exists in the project — there is no `.xcscheme` for tests, no `*Tests` group, and `ENABLE_TESTABILITY = YES` appears only for the main target.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Apple native, no third-party) |
| Config file | None — XCTest target must be added in Xcode via File > New > Target > Unit Testing Bundle |
| Quick run command | `xcodebuild test -scheme "Receipt TrackerTests" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:Receipt_TrackerTests` |
| Full suite command | `xcodebuild test -scheme "Receipt TrackerTests" -destination "platform=iOS Simulator,name=iPhone 16"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CTX-03 | `ciljevi` array appears in `finansije` block when goals are non-empty | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliContextBuilderTests/testCiljeviBlock` | ❌ Wave 0 |
| CTX-03 | `preostalo_meseci` is 0 for expired goals (past deadline) | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliContextBuilderTests/testExpiredGoalClampedToZero` | ❌ Wave 0 |
| CTX-03 | `finansije` block is created even when budget and income are absent but goals are present | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliContextBuilderTests/testFinansijeCreatedForGoalsOnly` | ❌ Wave 0 |
| CTX-04 | `TimeWindow(rawValue:)` correctly maps all 5 enum strings | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/TimeWindowTests/testAllCasesRoundTrip` | ❌ Wave 0 |
| CTX-04 | Unrecognized Haiku response falls back to `.recent` | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliServiceClassifyTests/testFallbackOnUnknownResponse` | ❌ Wave 0 (manual-only for live API; mock-able with stub) |
| CTX-05 | `buildSystemPrompt()` output contains "KATEGORIZACIJA" section header | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliServiceTests/testSystemPromptContainsKategorizacija` | ❌ Wave 0 |
| CTX-05 | System prompt mentions "Maxi" and "Lidl" in the namirnice group | unit | `xcodebuild test ... -only-testing:Receipt_TrackerTests/VorliServiceTests/testSystemPromptMerchantNames` | ❌ Wave 0 |

Notes on manual-only items: The live Haiku classification call (`classifyIntent()` with a real API key and real network) is manual-only for end-to-end validation. Unit tests should stub the network layer or test `TimeWindow(rawValue:)` directly without hitting the API.

### Sampling Rate
- **Per task commit:** Run `VorliContextBuilderTests` (pure logic, no network, no SwiftData)
- **Per wave merge:** Full suite including `TimeWindowTests` and `VorliServiceTests`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `Receipt TrackerTests/VorliContextBuilderTests.swift` — covers CTX-03 (`ciljevi` block, `preostalo_meseci` clamping, `finansije` guard condition)
- [ ] `Receipt TrackerTests/TimeWindowTests.swift` — covers CTX-04 (`TimeWindow` enum round-trip)
- [ ] `Receipt TrackerTests/VorliServiceTests.swift` — covers CTX-05 (system prompt string assertions)
- [ ] XCTest target: Add "Receipt Tracker Tests" unit test bundle target in Xcode — `xcodebuild test` will fail until this target exists

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `VorliChatViewModel.swift`, `VorliService.swift`, `VorliContextBuilder.swift`, `Receipt.swift`, `VorliChatView.swift`, `SettingsSheet.swift`, `Receipt_TrackerApp.swift`
- SwiftData `@Model` and `VersionedSchema` behavior: Apple official documentation (well-known for iOS 17+)
- `Calendar.dateComponents([.month], from:to:)`: Foundation standard library

### Secondary (MEDIUM confidence)
- Haiku model identifier `claude-haiku-4-20250514`: Inferred from the Sonnet ID already in `VorliService.swift` (`claude-sonnet-4-20250514`). Confirm against Anthropic model list before implementing.
- Non-streaming `AnthropicSyncResponse` shape: Inferred from Anthropic Messages API documentation (response body structure is stable and well-documented).

### Tertiary (LOW confidence)
- None — all findings grounded in direct code inspection or stable Apple/Anthropic API behavior.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new libraries, all patterns already in codebase
- Architecture: HIGH — all integration points identified from direct code reading; patterns match existing Phase 1 conventions
- Pitfalls: HIGH — SwiftData migration, double-send guard, and stale ViewModel are concrete issues identified from code structure, not speculation
- Validation: MEDIUM — test commands are structurally correct but the XCTest target does not yet exist; commands will need the correct scheme name once the target is created

**Research date:** 2026-03-12
**Valid until:** 2026-06-12 (stable Apple APIs; re-verify Haiku model ID if > 30 days)
