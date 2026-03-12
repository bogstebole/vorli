# Coding Conventions

**Analysis Date:** 2026-03-12

## Naming Patterns

**Files:**
- PascalCase for all Swift files matching the type they define: `ReceiptService.swift`, `VorliChatView.swift`
- View files end with `View` or `Sheet`: `ReceiptDetailView.swift`, `DashboardSheet.swift`
- ViewModel files end with `ViewModel`: `VorliChatViewModel.swift`
- Service files end with `Service`: `ReceiptService.swift`, `VorliService.swift`
- Parser files end with `Parser`: `ReceiptParser.swift`, `ReceiptOCRParser.swift`
- Shared UI components without suffix when standalone: `ReceiptCardView.swift`, `SectionDivider.swift`

**Types and Classes:**
- PascalCase for all types: `Receipt`, `ReceiptItem`, `VorliMessage`, `ParsedReceipt`
- Enum cases are camelCase: `.duplicateReceipt`, `.invalidURL`, `.user`, `.assistant`
- Error enums conform to `LocalizedError` and follow `<Domain>Error` pattern: `ReceiptError`, `VorliError`, `OCRError`

**Functions and Methods:**
- camelCase for all functions: `processReceipt(from:)`, `buildContext(for:)`, `parseLineItems(from:)`
- Private parsing helpers use descriptive verb-noun: `parseMerchantInfo`, `parseTotals`, `extractDecimal`
- Static factory methods use `load()` / `build(...)`: `VorliUserProfile.load()`, `VorliContextBuilder.build(...)`
- Boolean properties prefixed with `is`, `has`, `show`: `isStreaming`, `hasContent`, `showError`, `isAuthorized`

**Variables and Properties:**
- camelCase for all properties
- Private state in views declared `@State private var` with lowercase camelCase names
- Serbian-language domain terms used verbatim in model property names for AI context models: `mesecniPrihod`, `aktivniCilj`, `prodavnica`, `stavke`
- English used for all Swift infrastructure, Serbian used for domain-specific AI/display strings

## Code Style

**Formatting:**
- No automated formatter configured (no `.swiftformat`, `.editorconfig`, or SwiftLint config detected)
- 4-space indentation throughout
- Trailing commas on last items in multi-line initializers
- One blank line between functions, two blank lines between type definitions in the same file

**Access Control:**
- `private` applied consistently to helpers, internal state, and implementation details
- `private(set)` not observed; mutable properties exposed directly where needed
- `final` on classes that should not be subclassed: `final class VorliChatViewModel`, `final class Receipt`

**Type Annotations:**
- Omitted when type is inferred from literal assignment
- Required on function parameters and return types
- `Decimal` used for all monetary values (not `Double` or `Float`)

## Import Organization

**Order:**
1. Foundation
2. SwiftUI / SwiftData
3. Apple frameworks (UIKit, AVFoundation, Vision, PhotosUI, Observation)
4. No third-party imports visible at module level (Firebase referenced only in `Receipt_TrackerApp.swift` and commented-out auth files)

**Path Aliases:**
- None; standard module imports only

## MARK Sections

`// MARK: -` sections are used consistently to organize multi-section files. Standard sections observed:
- `// MARK: - State`
- `// MARK: - Private`
- `// MARK: - Methods`
- `// MARK: - Computed Properties`
- `// MARK: - Helper Functions`
- `// MARK: - Errors`
- `// MARK: - Parsed Models`

New types added to multi-type files should follow the same MARK sectioning.

## SwiftUI Patterns

**View Structure:**
- Views are `struct` conforming to `View`
- Sub-views within a file are extracted as `private struct` when used only internally
- Sub-views used across files are `public struct` (no explicit access modifier)
- `@ViewBuilder` used for conditional view factories within a view

**State Management:**
- `@State private var` for local UI state in views
- `@Environment(\.modelContext)` for SwiftData context injection
- `@Query` for fetching SwiftData collections directly in views
- `@Observable` + `@MainActor` for ViewModels (Swift Observation framework, not `ObservableObject`)
- `@Binding` passed explicitly into child views; `FocusState.Binding` passed directly for keyboard focus

**ViewModel Pattern:**
- `@MainActor final class` annotated with `@Observable`
- Owns service instances directly (no DI container)
- Instantiated lazily via `@State private var viewModel: SomeViewModel?` and created in `.task`

**Closures for Actions:**
- Action callbacks passed as closure parameters: `onScan: (String) -> Void`, `onAddBalance: () -> Void`
- `[weak self]` guard used in all closures that capture self: `{ [weak self] token in guard let self else { return } ... }`

## Error Handling

**Strategy:**
- Service layer throws typed errors (`ReceiptError`, `VorliError`, `OCRError`)
- Views catch with `do/catch` in async `Task` blocks and assign to `@State var errorMessage: String?`
- Errors surfaced via `.alert("Greška", isPresented: $showError) { ... } message: { Text(errorMessage) }`
- `try?` used to silence non-critical operations (delete, balance add, budget load in views) — error is swallowed
- `try?` used for regex initialization with compile-time-constant patterns (safe pattern)

**Error Localization:**
- All `LocalizedError` conformances provide Serbian-language `errorDescription`
- Error messages mix Serbian Cyrillic (`ReceiptError`) and Serbian Latin (`VorliError`, `OCRError`)

## Logging

**Framework:** `print()` statements directly (no logging library)

**Volume:** ~149 `print()` calls across the codebase, heavily concentrated in `ReceiptParser.swift` and `ReceiptOCRParser.swift` as debug instrumentation with emoji prefixes:
- `print("🔍 Starting OCR on image...")`
- `print("✅ ReceiptOCRParser returned successfully")`
- `print("Debug: Items section from line \(x) to \(y)")`

These are development-level debug logs, not production logging. No `os_log` or `Logger` usage.

## Comments

**Doc Comments:**
- `///` triple-slash used on all public and internal methods in service/parser types
- Example: `/// Fetches and parses a receipt from the given URL`
- Views generally do not have doc comments on `body`

**Inline Comments:**
- `//` inline comments used to label sections within `body` computed properties
- Multi-line explanatory comments use `//` not `/* */`
- Block comments `/* ... */` used only to comment out entire features (authentication code)

**"COMMENTED OUT FOR FIRST RELEASE":**
- Recurring comment marking deferred authentication features across `AuthenticationManager.swift`, `LoginView.swift`, `SignUpView.swift`, `PasswordResetView.swift`, `ContentView.swift`, `SettingsSheet.swift`, `Receipt_TrackerApp.swift`

## Function Design

**Size:** Service and parser functions range from 10 to 150+ lines. `parseLineItems(from:)` in `ReceiptParser.swift` is the largest single function (~260 lines) and is a known complexity hotspot.

**Parameters:** Named parameters with external labels; async functions use trailing `throws`; callbacks passed as labeled closure parameters (`onToken:`, `onComplete:`, `onError:`)

**Return Values:** Tuples used for multi-value returns from private parser helpers: `(name: String, address: String, city: String)`, `(total: Decimal, tax: Decimal, paymentMethod: String)`

## Module Design

**File Organization:**
- One primary type per file (with supporting private subtypes in the same file)
- Extensions in `Extensions.swift` for `Decimal`, `String`, and `Date`
- Parsed intermediate models (`ParsedReceipt`, `ParsedReceiptItem`) co-located at bottom of `ReceiptParser.swift`
- `// MARK: -` separates logical sections within a file

**Extensions:**
- Domain extensions centralized in `Extensions.swift`
- `extension QuickPrompt` with static `all` array in `VorliChatViewModel.swift` — co-located with the type that uses it

---

*Convention analysis: 2026-03-12*
