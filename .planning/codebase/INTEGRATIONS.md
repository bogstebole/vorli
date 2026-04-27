# External Integrations

**Analysis Date:** 2026-03-12

## APIs & External Services

**AI / LLM:**
- Anthropic Claude API — powers the Vorli AI financial assistant chat feature
  - Endpoint: `https://api.anthropic.com/v1/messages`
  - Model: `claude-sonnet-4-20250514` (hardcoded in `Receipt Tracker/VorliService.swift`)
  - Auth: API key stored in `UserDefaults` under `"vorli_anthropic_api_key"`, entered by user in `SettingsSheet.swift`
  - Protocol: SSE (Server-Sent Events) streaming via `URLSession.bytes(for:)` async
  - API version header: `anthropic-version: 2023-06-01`
  - Max tokens: 2048 per request
  - Context injection: receipt JSON serialized by `VorliContextBuilder.swift` is appended to user messages

**Serbian Fiscal Receipt Service:**
- `suf.purs.gov.rs` — Serbian government tax authority receipt verification portal
  - Usage: QR code on Serbian fiscal receipts encodes a URL to this domain; `ReceiptParser.swift` fetches the HTML and parses the `<pre>` block
  - Auth: None (public endpoint)
  - Client: `URLSession.shared.data(from:)` in `ReceiptParser.swift`
  - Only URLs containing `"suf.purs.gov.rs"` are accepted; others throw `ParserError.invalidURL`

## Data Storage

**Databases:**
- SwiftData (on-device SQLite) — primary persistent store
  - Schema: `Receipt`, `ReceiptItem`, `Budget`, `BudgetEntry` models in `Receipt Tracker/Receipt.swift`
  - Container configured in `Receipt Tracker/Receipt_TrackerApp.swift` with `isStoredInMemoryOnly: false`
  - No cloud sync (iCloud sync not configured)

**File Storage:**
- Local filesystem only — no cloud file storage in use

**Caching:**
- None — no explicit caching layer; SwiftData serves as the persistence layer

## Authentication & Identity

**Auth Provider:**
- None active — authentication is fully disabled for v1 release
  - All auth code is commented out in `Receipt Tracker/AuthenticationManager.swift` and `Receipt Tracker/SettingsSheet.swift`
  - `Receipt_TrackerApp.swift` bypasses auth and navigates directly to `ContentView`

**Prepared (inactive) implementations in `AuthenticationManager.swift`:**
- Firebase Email/Password — `Auth.auth().createUser` / `signIn(withEmail:password:)`
- Apple Sign In — `ASAuthorization` with SHA-256 nonce via `CryptoKit`; entitlement declared in `Receipt Tracker/Receipt Tracker.entitlements`
- Firebase as auth backend — `GoogleService-Info.plist` present for project `receipt-tracker-96a3d`

## Monitoring & Observability

**Error Tracking:**
- None — no Crashlytics, Sentry, or equivalent integrated

**Logs:**
- `print()` statements used during development (especially in `ReceiptService.swift` for OCR flow)
- No structured logging framework
- Firebase Analytics: disabled in `GoogleService-Info.plist` (`IS_ANALYTICS_ENABLED = false`)

## CI/CD & Deployment

**Hosting:**
- iOS App Store (Apple)

**CI Pipeline:**
- None detected — no `.github/`, `.gitlab-ci.yml`, `fastlane/`, or Xcode Cloud configuration found

## Environment Configuration

**Required configuration at runtime:**
- `"vorli_anthropic_api_key"` — Anthropic API key, entered by user in Settings UI (`SettingsSheet.swift`)
  - Without this key, Vorli AI returns `VorliError.missingAPIKey` with a Serbian-language error message

**User profile keys in UserDefaults (`VorliService.swift`):**
- `vorli_profile_prihod` — monthly income (Int, RSD)
- `vorli_profile_budzet` — budget model string (default: `"50/20/30"`)
- `vorli_profile_cilj` — savings goal string

**Firebase config file:**
- `GoogleService-Info.plist` — committed to repo; contains Firebase project ID (`receipt-tracker-96a3d`), GCM sender ID, and storage bucket

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None — all integrations are client-initiated (pull-based)

## On-Device Processing

**Vision Framework (Apple OCR):**
- `ReceiptOCRParser.swift` (project root directory) uses `VNRecognizeTextRequest` for on-device text extraction from receipt photos
- No data leaves the device during OCR processing
- Camera access: `AVFoundation` in `Receipt Tracker/QRScannerView.swift` for live camera feed; `PhotosUI` for photo library selection

---

*Integration audit: 2026-03-12*
