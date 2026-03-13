# Phase 3: Action Item Card Infrastructure - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning
**Source:** Figma design (node 148:15249) + conversation

<domain>
## Phase Boundary

Build a reusable card component for the Vorli chat UI that renders inline alongside text bubbles. Cards have a distinct visual style matching the provided Figma design, expose a primary action button, and support loading/disabled states. This phase is infrastructure only — no PDF generation or shopping list logic.

</domain>

<decisions>
## Implementation Decisions

### Card Visual Design (Figma-locked)
- Background: linear gradient from #F2F1F1 → #FFFFFF at ~100°
- Corner radius: 18pt
- Shadow: layered soft shadow (matching Figma shadow stack)
- Overall card width: fills chat bubble width (mirrors ~358pt reference)
- Left section: fixed-width (~66pt) thumbnail area — stacked/fanned mini receipt cards at slight angles with the front card showing the card type label (e.g. "PDF" in red SF Mono Bold, or a basket icon for shopping list)
- Right section: flexible, vertical stack with 8pt vertical padding
  - Row 1: title label (SF Mono Medium, 11pt) + circular action button (28×28pt, filled tertiary)
  - Row 2: main text (SF Mono Medium, 14pt, #111110)
  - Row 3: meta info (SF Mono Regular, 11pt, #8A8A82) — receipt count + total spent or item count

### Typography
- All text uses SF Mono (not SF Pro) — matches the existing Vorli chat aesthetic
- Title: SF Mono Medium 11pt
- Main text: SF Mono Medium 14pt
- Meta: SF Mono Regular 11pt, color #8A8A82

### Action Button
- Small circular button (28×28pt), SF symbol inside
- PDF card: download symbol (􀈅)
- Shopping list card: a share or view symbol
- Disabled/loading state: button dimmed, non-interactive

### Card Types (Phase 3 infrastructure must support both)
1. **PDF Report card** — thumbnail shows stacked receipts + "PDF" label; main text = month name; meta = receipt count + total RSD
2. **Shopping List card** — thumbnail shows stacked item/basket icons; main text = list title; meta = item count

### Loading / Generating State
- Card renders immediately when Vorli decides to emit one
- While generating: thumbnail area shows a shimmer or placeholder, action button is disabled
- Once ready: action button becomes active

### ViewModel Integration
- `VorliMessage` must support a card payload variant alongside the existing text variant
- `VorliChatViewModel` emits card messages; the view renders them using the card component
- Card payload carries: type (pdf | shoppingList), title, metaLine, actionState (loading | ready | disabled)

### Claude's Discretion
- Exact shimmer/skeleton animation style
- Whether card payload is an enum case on `VorliMessage` or a separate type
- How card thumbnail assets are sourced (SF Symbols, local assets, or drawn in SwiftUI)
- Exact padding/spacing tweaks to match Figma at different Dynamic Type sizes

</decisions>

<specifics>
## Specific References

- Figma file: https://www.figma.com/design/ULaJyQwAFQMjnbCL32ztCC/Receipt?node-id=148-15249
- Figma node ID: 148:15249
- Card screenshot confirmed: rounded card, stacked receipt thumbnails left, SF Mono text right, circular download button top-right of text area
- "PDF" label on front thumbnail is #EB4322 red, SF Mono Bold
- Meta separator is a plain dash `-` in Geist Regular between the two meta segments

</specifics>

<deferred>
## Deferred Ideas

- Actual PDF generation (Phase 4)
- Actual shopping list generation (Phase 5)
- Price comparison in cards (Phase 6)
- Haptic feedback on card button tap
- Card expand/collapse animation

</deferred>

---

*Phase: 03-action-item-card-infrastructure*
*Context gathered: 2026-03-13 from Figma design session*
