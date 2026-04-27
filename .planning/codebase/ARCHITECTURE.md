# Architecture

**Analysis Date:** 2026-03-12

## Pattern Overview

**Overall:** MVVM on SwiftUI with SwiftData persistence

**Key Characteristics:**
- Single-screen app rooted at `ContentView` — no tab controller in production (MainTabView exists only for debug builds)
- Service layer (`ReceiptService`, `VorliService`) mediates between SwiftData and the UI
- AI feature (`VorliChatView`) uses MVVM with an `@Observable` ViewModel; main receipt list does not use a dedicated ViewModel — state lives directly in the View
- All data mutations run on `@MainActor`; async work uses Swift concurrency (`async/await` + `Task`)

## Layers

**Models (SwiftData):**
- Purpose: Persisted data schema; source of truth for all receipt and budget data
- Location: `Receipt Tracker/Receipt.swift`
- Contains: `Receipt`, `ReceiptItem`, `Budget`, `BudgetEntry` — all annotated `@Model`
- Depends on: SwiftData framework only
- Used by: ReceiptService, ContentView (`@Query`), VorliChatView (`@Query`), DashboardSheet

**Service Layer:**
- Purpose: Encapsulates all SwiftData mutations and async parsing; Views do not write to `modelContext` directly
- Location: `Receipt Tracker/ReceiptService.swift`
- Contains: CRUD for receipts, budget deduction/refund, balance entries
- Depends on: SwiftData `ModelContext`, `ReceiptParser`, `ReceiptOCRParser` (in `ReceiptOCRParser.swift` at project root)
- Used by: `ContentView` (instantiates ad-hoc per operation)

**Parsers:**
- Purpose: Convert external data sources (Serbian fiscal URLs, camera images) into `ParsedReceipt` value types
- Location:
  - `Receipt Tracker/ReceiptParser.swift` — HTML scraper for `suf.purs.gov.rs`
  - `ReceiptOCRParser.swift` (project root) — Vision/OCR-based image parser
- Contains: Static `parseReceipt(from:)` methods returning `ParsedReceipt`
- Depends on: `Foundation`, `Vision` (OCR), `URLSession`
- Used by: `ReceiptService` only

**AI Layer:**
- Purpose: Claude-powered expense assistant ("Vorli"); isolated from receipt CRUD
- Location:
  - `Receipt Tracker/VorliService.swift` — Anthropic API client with SSE streaming
  - `Receipt Tracker/VorliChatViewModel.swift` — `@Observable` ViewModel managing message state and context selection
  - `Receipt Tracker/VorliContextBuilder.swift` — Serialises SwiftData receipts to JSON for prompt injection
- Depends on: `VorliService` (API), `VorliContextBuilder` (prompt building), SwiftData receipts (read-only)
- Used by: `VorliChatView`

**Views:**
- Purpose: Declarative UI; read from SwiftData via `@Query` or receive data as props
- Location: `Receipt Tracker/` (all `*View.swift`, `*Sheet.swift`)
- Depends on: Service layer for writes; SwiftData via environment for reads
- Used by: App entry point

## Data Flow

**Scanning a QR receipt:**

1. User taps scan button in `ContentView`; `showScanner = true` presents `QRScannerView`
2. `QRScannerView` (AVFoundation) detects QR code, calls `onScan(urlString)` closure
3. `ContentView.processReceipt(from:)` creates `ReceiptService` and calls `service.processReceipt(from:)`
4. `ReceiptService` calls `ReceiptParser.parseReceipt(from:)` — fetches HTML from fiscal URL, returns `ParsedReceipt`
5. `ReceiptService` checks for duplicates, creates `Receipt`+`ReceiptItem` objects, deducts from `Budget`
6. Objects inserted into `ModelContext` and saved; `Receipt` returned to View
7. `ContentView` sets `scannedReceipt` to trigger `navigationDestination` → `ReceiptDetailView`

**Scanning a physical receipt image:**

1. Same entry path, but `onReceiptScan(UIImage)` closure is called instead
2. `ReceiptService.processReceiptImage(_:)` calls `ReceiptOCRParser.parseReceipt(from:)` (Vision OCR)
3. Same save path as QR flow

**Vorli AI chat:**

1. User opens `VorliChatView` (fullScreenCover); `@Query` fetches all receipts
2. `.task` creates `VorliChatViewModel(allReceipts:)`
3. User submits text or quick prompt → `ViewModel.send(_:requestType:)`
4. `VorliContextBuilder.build(...)` serialises relevant receipts to JSON string
5. `VorliService.sendMessage(...)` opens SSE stream to `https://api.anthropic.com/v1/messages`
6. Each SSE token calls `onToken` → ViewModel appends to last message's `content` string
7. View re-renders via `@Observable` binding

**State Management:**
- Persistent state: SwiftData `ModelContainer` injected at app root via `.modelContainer(sharedModelContainer)`
- Ephemeral view state: `@State` properties in each View
- AI chat state: `VorliChatViewModel` (`@Observable`) owned by `VorliChatView`
- User preferences: `UserDefaults` (Anthropic API key, Vorli user profile fields)

## Key Abstractions

**ParsedReceipt (value type):**
- Purpose: Intermediate representation between parser output and SwiftData model creation
- Examples: Returned by `ReceiptParser.parseReceipt(from:)` and `ReceiptOCRParser.parseReceipt(from:)`
- Pattern: Struct with same fields as `Receipt` model; ReceiptService converts it to `@Model` class

**VorliMessage:**
- Purpose: Chat message value type used throughout AI layer
- Examples: `Receipt Tracker/VorliService.swift`
- Pattern: Struct with `role: Role` enum (`.user`/`.assistant`) and mutable `content: String` for streaming

**VorliUserProfile:**
- Purpose: User financial profile for AI personalisation; persisted in UserDefaults
- Examples: `Receipt Tracker/VorliService.swift` — `static func load()` / `func save()`
- Pattern: Plain struct with static load/save; no ViewModel wrapper

## Entry Points

**App Entry:**
- Location: `Receipt Tracker/Receipt_TrackerApp.swift`
- Triggers: iOS app launch
- Responsibilities: Configures Firebase (`AppDelegate`), creates `ModelContainer` with all four schemas, presents `ContentView`

**Main Screen:**
- Location: `Receipt Tracker/ContentView.swift`
- Triggers: Shown directly by app entry (auth gate commented out for v1)
- Responsibilities: Displays monthly receipt list, hosts all sheet presentations, triggers scan/AI flows

**Vorli Entry:**
- Location: `Receipt Tracker/VorliChatView.swift`
- Triggers: `fullScreenCover` from `ContentView` toolbar sparkles button
- Responsibilities: Initialises ViewModel with live receipt data, renders chat UI

## Error Handling

**Strategy:** Throw from service/parser; catch in View; display via `Alert`

**Patterns:**
- Parsers throw typed `enum` errors conforming to `LocalizedError` (e.g., `ReceiptParser.ParserError`, `ReceiptError`, `VorliError`)
- `ContentView` wraps async calls in `do/catch`, sets `errorMessage: String?` + `showError: Bool`, renders `.alert`
- `VorliChatViewModel` exposes `errorMessage` and `showError` as `@Observable` properties; View binds alert to them

## Cross-Cutting Concerns

**Localisation:** Serbian Latin locale used throughout; `DateFormatter`, `NumberFormatter` created with `Locale(identifier: "sr_Latn_RS")` or `"sr_RS"`. UI strings are hardcoded in Serbian.

**Validation:** Done inline in parsers (URL scheme check, regex matches). No separate validation layer.

**Authentication:** Fully commented out for v1. Firebase Auth + Apple Sign-In code preserved in `AuthenticationManager.swift` but the entire class is wrapped in `/* */`. All auth-related UI in `SettingsSheet` and `ContentView` is also commented out.

**Concurrency:** `@MainActor` on all service classes and ViewModels. Async work dispatched with `Task { }`. Streaming SSE handled by `URLSession.bytes(for:)` async sequence.

---

*Architecture analysis: 2026-03-12*
