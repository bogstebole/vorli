# Phase 3: Action Item Card Infrastructure - Research

**Researched:** 2026-03-13
**Domain:** SwiftUI custom card component, Swift enum-based message payload, iOS 17+ animations
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Card Visual Design (Figma-locked)**
- Background: linear gradient from #F2F1F1 → #FFFFFF at ~100°
- Corner radius: 18pt
- Shadow: layered soft shadow (matching Figma shadow stack)
- Overall card width: fills chat bubble width (mirrors ~358pt reference)
- Left section: fixed-width (~66pt) thumbnail area — stacked/fanned mini receipt cards at slight angles with the front card showing the card type label (e.g. "PDF" in red SF Mono Bold, or a basket icon for shopping list)
- Right section: flexible, vertical stack with 8pt vertical padding
  - Row 1: title label (SF Mono Medium, 11pt) + circular action button (28×28pt, filled tertiary)
  - Row 2: main text (SF Mono Medium, 14pt, #111110)
  - Row 3: meta info (SF Mono Regular, 11pt, #8A8A82) — receipt count + total spent or item count

**Typography**
- All text uses SF Mono (not SF Pro) — matches the existing Vorli chat aesthetic
- Title: SF Mono Medium 11pt
- Main text: SF Mono Medium 14pt
- Meta: SF Mono Regular 11pt, color #8A8A82

**Action Button**
- Small circular button (28×28pt), SF symbol inside
- PDF card: download symbol
- Shopping list card: a share or view symbol
- Disabled/loading state: button dimmed, non-interactive

**Card Types (Phase 3 infrastructure must support both)**
1. PDF Report card — thumbnail shows stacked receipts + "PDF" label; main text = month name; meta = receipt count + total RSD
2. Shopping List card — thumbnail shows stacked item/basket icons; main text = list title; meta = item count

**Loading / Generating State**
- Card renders immediately when Vorli decides to emit one
- While generating: thumbnail area shows a shimmer or placeholder, action button is disabled
- Once ready: action button becomes active

**ViewModel Integration**
- `VorliMessage` must support a card payload variant alongside the existing text variant
- `VorliChatViewModel` emits card messages; the view renders them using the card component
- Card payload carries: type (pdf | shoppingList), title, metaLine, actionState (loading | ready | disabled)

### Claude's Discretion
- Exact shimmer/skeleton animation style
- Whether card payload is an enum case on `VorliMessage` or a separate type
- How card thumbnail assets are sourced (SF Symbols, local assets, or drawn in SwiftUI)
- Exact padding/spacing tweaks to match Figma at different Dynamic Type sizes

### Deferred Ideas (OUT OF SCOPE)
- Actual PDF generation (Phase 4)
- Actual shopping list generation (Phase 5)
- Price comparison in cards (Phase 6)
- Haptic feedback on card button tap
- Card expand/collapse animation
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UX-01 | Chat displays action item cards inline (PDF report card, shopping list card) — not just text | VorliMessage payload extension + ChatMessagesView switch on content type |
| UX-02 | Action item cards have a download/share action (PDF export, list export) | UIActivityViewController wrapped as SwiftUI sheet; action button triggers it from card |
</phase_requirements>

---

## Summary

Phase 3 is a pure SwiftUI infrastructure phase. The core work is: extend `VorliMessage` so its content can be either a text string or a typed card payload, update `ChatMessagesView` to branch on that content type and render an `ActionItemCardView` component, and build that component to match the Figma spec.

The existing `VorliMessage` struct is a simple `Identifiable, Equatable, Codable` struct with a `String content` property. Extending it cleanly requires either (a) changing `content` to an enum with associated values, or (b) adding an optional `cardPayload` field alongside the existing `content` string. Both approaches work; the enum approach is cleaner and aligns with the project's existing pattern of using enums for typed state (see `TimeWindow`, `Role`). The tradeoff is that `Codable` conformance must be hand-written for an enum with associated values — a known but small overhead.

`VorliChatSession` persists `[VorliMessage]` via `JSONEncoder` to `UserDefaults`. Any change to `VorliMessage`'s `Codable` shape must keep existing sessions decodable or sessions will silently fail to load. A versioned enum approach with a `text` case that maps to the current flat `content` field is the safe migration path.

**Primary recommendation:** Add a `VorliCardPayload` struct (Codable), change `VorliMessage.content` to an enum `VorliMessageContent` with cases `.text(String)` and `.card(VorliCardPayload)`, and branch in `ChatMessagesView` with a `switch` on `message.content`. The card component is a standalone `ActionItemCardView` struct that takes a `VorliCardPayload` binding.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Card layout, gradient, animation | Already in use throughout app |
| Foundation | iOS 17+ | Codable, UUID, JSONEncoder | Already in use |
| UIKit (via representable) | iOS 17+ | Share sheet (UIActivityViewController) | Only UIKit exposes the native share sheet; SwiftUI `.shareLink` is the wrapper but `UIActivityViewController` gives full control |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI `.shareLink` | iOS 16+ | Share sheet for exportable items | Use for simple URL/file sharing; already available in project |
| SwiftUI `LinearGradient` | iOS 13+ | Card background gradient | Use for the Figma-specified #F2F1F1 → #FFFFFF gradient |
| SwiftUI `@keyframeAnimator` / `withAnimation` | iOS 17+ | Shimmer animation on loading state | Use for the loading skeleton; no third-party needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Enum `VorliMessageContent` with associated values | Optional `cardPayload: VorliCardPayload?` on `VorliMessage` | Optional field is simpler Codable but less type-safe; enum prevents a message from having both text and card simultaneously |
| SwiftUI-drawn thumbnail stacking | UIKit-based custom view | Pure SwiftUI `.rotationEffect` + `ZStack` offset achieves the stacked fan; no UIKit needed |
| `UIActivityViewController` wrapper | SwiftUI `.shareLink` | `.shareLink` is cleaner for simple exports but doesn't support all share targets; `UIActivityViewController` is more flexible for Phase 4 PDF data |

**Installation:** No new dependencies — all work is pure SwiftUI + Foundation.

---

## Architecture Patterns

### Recommended File Structure
```
Receipt Tracker/
├── VorliService.swift              # VorliMessage + VorliCardPayload types live here (existing)
├── VorliChatViewModel.swift        # Add emitCard() helper method
├── VorliChatView.swift             # ChatMessagesView gets card branch; ActionItemCardView added
└── (no new files strictly required — card view can live in VorliChatView.swift
    or split into ActionItemCardView.swift for clarity)
```

### Pattern 1: Enum-based Message Content

**What:** `VorliMessage.content` becomes a `VorliMessageContent` enum with `.text(String)` and `.card(VorliCardPayload)` cases. Hand-rolled `Codable` uses a `type` discriminator field for forward compatibility.

**When to use:** Any time a message carries structured non-text data.

```swift
// Source: Swift Evolution SE-0155 / Swift 5.5 Codable pattern
enum VorliMessageContent: Equatable {
    case text(String)
    case card(VorliCardPayload)
}

extension VorliMessageContent: Codable {
    private enum CodingKeys: String, CodingKey { case type, text, card }
    private enum ContentType: String, Codable { case text, card }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(s, forKey: .text)
        case .card(let c):
            try container.encode(ContentType.card, forKey: .type)
            try container.encode(c, forKey: .card)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(ContentType.self, forKey: .type)
        switch type_ {
        case .text:
            self = .text(try container.decode(String.self, forKey: .text))
        case .card:
            self = .card(try container.decode(VorliCardPayload.self, forKey: .card))
        }
    }
}
```

### Pattern 2: VorliCardPayload Struct

**What:** A typed struct carrying all card data. Fully `Codable` for session persistence.

```swift
struct VorliCardPayload: Equatable, Codable {
    enum CardType: String, Codable { case pdf, shoppingList }
    enum ActionState: String, Codable { case loading, ready, disabled }

    let type: CardType
    var title: String           // e.g. "Mart 2026"
    var metaLine: String        // e.g. "12 računa · 45.320 RSD"
    var actionState: ActionState
}
```

### Pattern 3: ChatMessagesView Branch

**What:** `ChatMessagesView` switches on `message.content` to dispatch to either the existing text view or the new card view. No changes to the outer ForEach structure.

```swift
// In ChatMessagesView ForEach body:
if message.role == .user {
    UserMessageBubble(text: message.textContent ?? "")
        .id(message.id)
} else {
    switch message.content {
    case .text(let t):
        AIResponseView(text: t, isStreaming: isStreaming && message == messages.last)
            .id(message.id)
    case .card(let payload):
        ActionItemCardView(payload: payload)
            .id(message.id)
    }
}
```

### Pattern 4: Stacked Thumbnail (SwiftUI, no UIKit)

**What:** Two or three mini card shapes stacked with `ZStack` + `rotationEffect` + `offset` to produce the Figma fan effect.

```swift
// Figma fan: back cards rotate slightly, front card is upright
ZStack {
    RoundedRectangle(cornerRadius: 6)
        .fill(Color(.systemGray5))
        .frame(width: 44, height: 56)
        .rotationEffect(.degrees(-8))
        .offset(x: -4, y: 2)
    RoundedRectangle(cornerRadius: 6)
        .fill(Color(.systemGray4))
        .frame(width: 44, height: 56)
        .rotationEffect(.degrees(-3))
        .offset(x: -2, y: 1)
    // Front card — shows PDF label or basket icon
    RoundedRectangle(cornerRadius: 6)
        .fill(.white)
        .frame(width: 44, height: 56)
        .overlay { /* type label or SF Symbol */ }
}
.frame(width: 66, height: 72)
```

### Pattern 5: Shimmer Loading Animation

**What:** A moving gradient overlay on the thumbnail area that animates while `actionState == .loading`.

```swift
// Source: Apple WWDC 2023 — "Animate with springs" / standard redacted shimmer pattern
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content.overlay(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: phase - 0.3),
                    .init(color: .white.opacity(0.5), location: phase),
                    .init(color: .clear, location: phase + 0.3),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: phase)
        )
        .onAppear { phase = 1.3 }
        .clipped()
    }
}
```

### Anti-Patterns to Avoid

- **Changing `content: String` in place without a Codable migration:** Existing persisted sessions encode `content` as a bare string. If you change the property type without a migration decoder, `VorliSessionStore.load()` will silently return `[]`. Use the discriminated union approach above.
- **Using `@Binding` for card payload in the view:** Cards are read-only display components at this phase (Phase 4/5 will update `actionState` from outside). Pass the payload as `let payload: VorliCardPayload` — if the ViewModel updates it, the view will re-render via `@Observable` on `VorliChatViewModel`.
- **Putting `ActionItemCardView` in a `LazyVStack` with `.animation` on the card itself:** `LazyVStack` already recycles views. Attach `.animation` to the loading state modifier, not the card's existence, to avoid flicker on scroll.
- **Using `UIActivityViewController` directly in a `Button` action without a wrapping state flag:** Present via a `@State var showShareSheet = false` + `.sheet(isPresented:)` pattern, not inline in a button closure — direct presentation crashes on iPad without a `sourceView`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Share sheet | Custom share UI | SwiftUI `.shareLink(item:)` or `UIActivityViewController` wrapped in `.sheet` | Share sheet has dozens of extension points; custom UI misses AirDrop, Files, Messages |
| Gradient background | Manual `drawRect` | SwiftUI `LinearGradient` with `stops:` | One-liner, GPU-accelerated, respects color scheme |
| Shimmer animation | Third-party shimmer library | Custom `ViewModifier` with animated `LinearGradient` | No dependency, ~15 lines, full control of timing |
| Codable for enum with associated values | JSON parsing by hand | Swift's `Codable` with manual `encode/init(from:)` | Standard pattern, compile-checked, no runtime string parsing |

**Key insight:** This phase is entirely additive SwiftUI — no new dependencies are justified. The complexity ceiling is the Codable migration for `VorliMessage`.

---

## Common Pitfalls

### Pitfall 1: Session Deserialization Break
**What goes wrong:** Changing `VorliMessage.content` from `String` to an enum breaks `JSONDecoder().decode([VorliChatSession].self, ...)` for existing persisted sessions. Sessions silently return `[]` — the user loses all chat history.
**Why it happens:** `VorliChatSession` is persisted to `UserDefaults` as JSON. The `content` key currently encodes a bare string. After the type change, the decoder expects a nested object with a `type` discriminator.
**How to avoid:** In `VorliMessageContent.init(from:)`, add a fallback path: if the `type` key is missing, attempt to decode `content` as a bare `String` and return `.text(string)`. This makes old sessions loadable.
**Warning signs:** Running the app after the model change and finding the chat history list empty.

### Pitfall 2: Card Width in Chat Scroll View
**What goes wrong:** Card renders at full screen width instead of matching the AI response bubble width, breaking visual consistency.
**Why it happens:** `ActionItemCardView` uses `.frame(maxWidth: .infinity)` without being constrained by the same leading `Spacer` pattern used by `AIResponseView`.
**How to avoid:** Wrap `ActionItemCardView` in the same `HStack(alignment: .top) { VStack { ... }; Spacer(minLength: 40) }` container that `AIResponseView` uses. The Figma 358pt reference is a max-width at 390pt iPhone screen.
**Warning signs:** Card touches the trailing edge of the screen while text responses do not.

### Pitfall 3: Share Sheet Crash on iPad
**What goes wrong:** Presenting `UIActivityViewController` directly without setting `popoverPresentationController.sourceView` crashes on iPad with `NSInternalInconsistencyException`.
**Why it happens:** iPads require a source rect for share sheet popovers.
**How to avoid:** Use SwiftUI's `.shareLink(item:)` for URL/file sharing (iOS 16+, already in deployment target). For Phase 3 (stub action), a `ShareLink` with a placeholder `URL` or the card title as text is sufficient.
**Warning signs:** Crash only reproducible on iPad simulator, not iPhone.

### Pitfall 4: SF Mono Font Availability
**What goes wrong:** `.font(.custom("SFMono-Medium", size: 11))` returns system fallback silently — the card renders in SF Pro instead of SF Mono.
**Why it happens:** SF Mono's PostScript name is not publicly documented and may differ across iOS versions.
**How to avoid:** Use `.font(.system(size: 11, design: .monospaced))` with explicit weight — this is how the existing codebase accesses SF Mono (confirmed in `VorliChatView.swift` throughout). Do not use `.custom()`.
**Warning signs:** Card text appears in proportional font despite `.custom("SFMono-...")` being set.

### Pitfall 5: `@Observable` ViewModel and Card State Updates
**What goes wrong:** Updating `messages[index].content` (for changing `actionState` from `.loading` to `.ready`) doesn't trigger a view update because `messages` is a value-type array of structs.
**Why it happens:** SwiftUI tracks changes to `@Observable` properties at the property level. Mutating an element inside `[VorliMessage]` — a value-type array — does trigger re-render because the array itself changes, but only if the mutation happens through the `@Observable`-tracked `messages` property setter (not through `withUnsafeMutableBufferPointer`).
**How to avoid:** Always mutate card state via `viewModel.messages[idx].content = .card(updatedPayload)` — the standard subscript assignment path. This is already how `onToken` appends streaming text in `VorliChatViewModel`.
**Warning signs:** Button stays in `.loading` appearance even after `.ready` is set programmatically.

---

## Code Examples

### Full ActionItemCardView Layout Skeleton

```swift
// Source: VorliChatView.swift layout patterns + Figma spec 148:15249
struct ActionItemCardView: View {
    let payload: VorliCardPayload

    var body: some View {
        HStack(spacing: 0) {
            // Left: thumbnail area, fixed 66pt wide
            CardThumbnailView(type: payload.type, actionState: payload.actionState)
                .frame(width: 66)

            // Right: text + action button
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(payload.title)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    CardActionButton(payload: payload)
                }
                .padding(.bottom, 2)

                Text(payload.mainText)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#111110"))

                Text(payload.metaLine)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(hex: "#8A8A82"))
            }
            .padding(.vertical, 8)
            .padding(.trailing, 12)
            .padding(.leading, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#F2F1F1"), .white],
                startPoint: UnitPoint(x: cos(100 * .pi / 180), y: sin(100 * .pi / 180)),
                endPoint: UnitPoint(x: cos(100 * .pi / 180 + .pi), y: sin(100 * .pi / 180 + .pi))
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        // Figma-matching layered shadow (same pattern as ChatHistoryCardView)
        .shadow(color: .black.opacity(0.04), radius: 1.5, x: 0, y: 1)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 6)
        .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 13)
        .shadow(color: .black.opacity(0.01), radius: 4.5, x: 0, y: 24)
    }
}
```

### VorliMessage Content Migration (Codable backward compat)

```swift
// Backward-compatible decoder: accepts old bare-string `content` from persisted sessions
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type_ = try? container.decode(ContentType.self, forKey: .type)
    switch type_ {
    case .text, .none:
        // .none handles old sessions where `type` key didn't exist
        let raw = try container.decode(String.self, forKey: .text)
        self = .text(raw)
    case .card:
        self = .card(try container.decode(VorliCardPayload.self, forKey: .card))
    }
}
```

### Emitting a Card from VorliChatViewModel

```swift
// Called by Phase 4/5 when Vorli decides to emit a card instead of text
func emitCard(_ payload: VorliCardPayload) {
    let cardMsg = VorliMessage(role: .assistant, content: .card(payload))
    messages.append(cardMsg)
}

// Updating card state (e.g. loading → ready after PDF generation):
func updateCardState(messageID: UUID, newState: VorliCardPayload.ActionState) {
    guard let idx = messages.firstIndex(where: { $0.id == messageID }),
          case .card(var payload) = messages[idx].content else { return }
    payload.actionState = newState
    messages[idx].content = .card(payload)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `UICollectionView` custom cells for chat | SwiftUI `LazyVStack` + `ForEach` | iOS 16+ mainstream | Pure SwiftUI is viable for production chat UIs at this scale |
| `UIActivityViewController` wrapped as `UIViewControllerRepresentable` | SwiftUI `.shareLink(item:)` | iOS 16 | Cleaner; handles iPad source rect automatically |
| Manual `Codable` for all enum cases | Synthesized `Codable` for simple enums | Swift 5.5+ | Synthesized works only for enums without associated values; hand-rolled still needed here |

**Deprecated/outdated:**
- `.redacted(reason: .placeholder)`: Apple's built-in skeleton view — suitable for loading states but produces a uniform grey wash that won't match the Figma shimmer. Use a custom `ShimmerModifier` instead (see Pattern 5 above).

---

## Open Questions

1. **VorliMessage.content field rename**
   - What we know: `content` is a `var` used in `messages[assistantIndex].content += token` for streaming. Changing the type breaks that `+=` operator.
   - What's unclear: Whether to keep a `var textContent: String` computed property for streaming compatibility, or change the streaming path to use a separate `streamingBuffer` on the ViewModel.
   - Recommendation: Add a `var textContent: String` computed property on `VorliMessage` that returns the string for `.text` case and `""` for `.card` — then streaming path remains `messages[idx].content = .text(messages[idx].textContent + token)`. Slightly more verbose but no architectural change to `VorliService`.

2. **Gradient angle in SwiftUI**
   - What we know: Figma specifies ~100° linear gradient. SwiftUI `LinearGradient` takes `startPoint`/`endPoint` as `UnitPoint`, not degrees.
   - What's unclear: Exact `UnitPoint` translation of 100° that matches Figma visually. Figma's 0° is top → bottom; 100° is slightly past left → right (clockwise).
   - Recommendation: Use `startPoint: UnitPoint(x: 0, y: 0.5)` and `endPoint: UnitPoint(x: 1, y: 0.7)` as a close approximation and visually verify against Figma screenshot. Adjust in a single commit.

3. **`VorliCardPayload.mainText` vs `title`**
   - What we know: CONTEXT.md specifies `title` (11pt) + main text (14pt) + meta (11pt) as three separate rows. The payload struct needs all three.
   - What's unclear: Whether `title` and `mainText` should be separate fields or if `title` IS the card type label (e.g. "PDF izveštaj") while `mainText` is the specific value (e.g. "Mart 2026").
   - Recommendation: Keep them separate fields — `title: String` for the type label row and `mainText: String` for the prominent value row. Phase 4/5 populates both.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing, in "Receipt Tracker Tests" target) |
| Config file | Receipt Tracker Tests/ target in Xcode project |
| Quick run command | `xcodebuild test -scheme "Receipt Tracker" -destination "platform=iOS Simulator,name=iPhone 17" -testPlan Receipt_Tracker_Tests 2>&1 | grep -E "(Test Suite|PASS|FAIL|error:)"` |
| Full suite command | `xcodebuild test -scheme "Receipt Tracker" -destination "platform=iOS Simulator,name=iPhone 17" 2>&1 | tail -20` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-01 | `VorliMessage` with `.card` content encodes and decodes correctly (roundtrip) | unit | `xcodebuild test ... -only-testing:Receipt_Tracker_Tests/VorliMessageTests` | ❌ Wave 0 |
| UX-01 | `VorliMessage` with old bare-string `content` decodes without crash (backward compat) | unit | same | ❌ Wave 0 |
| UX-01 | `VorliChatViewModel.emitCard()` appends a message with `.card` content | unit | same | ❌ Wave 0 |
| UX-02 | `VorliCardPayload.ActionState` transitions from `.loading` to `.ready` update message correctly | unit | same | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Run `VorliMessageTests` suite only (~2 seconds)
- **Per wave merge:** Full `xcodebuild test` suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `Receipt Tracker Tests/VorliMessageTests.swift` — covers UX-01, UX-02 (Codable roundtrip, backward compat decode, emitCard, updateCardState)
- [ ] No framework install needed — XCTest target already exists

---

## Sources

### Primary (HIGH confidence)
- Codebase direct inspection: `VorliChatView.swift`, `VorliChatViewModel.swift`, `VorliService.swift` — current architecture, `VorliMessage` shape, `ChatMessagesView` render loop, session persistence path
- Swift documentation (training knowledge, stable API): `Codable` manual implementation pattern for enums with associated values
- Existing `ChatHistoryCardView` in `VorliChatView.swift` — Figma-matching layered shadow values already present in codebase (copied directly)

### Secondary (MEDIUM confidence)
- Figma design reference node 148:15249 (cited in CONTEXT.md) — visual spec for card layout, dimensions, colors
- SwiftUI `LinearGradient` + `UnitPoint` — angle-to-UnitPoint conversion approximation (visual verification needed)

### Tertiary (LOW confidence)
- SF Mono PostScript name variability across iOS versions — inferred from codebase pattern (`design: .monospaced`) not from official Apple type documentation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all technologies are currently in use in the project, zero new dependencies
- Architecture: HIGH — `VorliMessage` shape and `ChatMessagesView` structure fully inspected; enum+Codable pattern is standard Swift
- Pitfalls: HIGH (session break, font, share sheet crash) / MEDIUM (gradient angle UnitPoint approximation)
- Validation: HIGH — XCTest target confirmed present; test file list confirmed by directory listing

**Research date:** 2026-03-13
**Valid until:** 2026-06-13 (stable iOS/SwiftUI APIs; Figma spec locked by user decision)
