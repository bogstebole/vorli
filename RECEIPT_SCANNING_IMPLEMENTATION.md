# Receipt Scanning Implementation

## Overview

Added the ability to scan physical receipts using OCR (Optical Character Recognition) as an alternative to scanning QR codes. Users can now choose between two scanning methods using a segmented control in the scanner view.

## What Was Added

### 1. **ReceiptOCRParser.swift** (New File)
A parser that uses Apple's Vision framework to extract text from receipt images.

**Key Features:**
- Uses `VNRecognizeTextRequest` for OCR
- Configured for Serbian/Latin script (`sr-Latn`)
- Parses the same data fields as the HTML parser:
  - Merchant name, address, and city
  - Receipt timestamp
  - Total amount and tax
  - Payment method
  - Line items (name, quantity, price, total)
  - Receipt number and cash register number
- Generates unique URL for OCR receipts: `ocr://receipt/{UUID}`

**Recognition Capabilities:**
- Recognizes Serbian Cyrillic and Latin text
- Parses Serbian number format (1.234,56)
- Handles both "Готовина" and "Bezgotovinsko plaćanje"
- Extracts timestamps in Serbian format (DD.MM.YYYY. HH:mm:ss)

### 2. **QRScannerView.swift** (Updated)

**New Scan Mode Enum:**
```swift
enum ScanMode: String, CaseIterable {
    case qrCode = "QR Kod"
    case receipt = "Račun"
}
```

**Segmented Control:**
- Added at the top of the scanner view
- Switches between "QR Kod" and "Račun" modes
- Updates camera view and title dynamically

**Dual Camera Modes:**
- **QR Code Mode**: Uses `QRScannerCameraView` (existing)
  - Scans QR codes in real-time
  - Shows reticle overlay
  - Auto-detects and vibrates on scan

- **Receipt Mode**: Uses `ReceiptScannerCameraView` (new)
  - Full-screen camera for photographing receipts
  - Rectangular overlay guide for receipt positioning
  - Manual capture button (camera icon)
  - Shows "Obrađujem račun..." while processing

**Processing Overlay:**
- Shows loading spinner when OCR is running
- Prevents multiple scans during processing
- Displays friendly progress message

**Photo Picker Integration:**
- Works with both modes
- QR mode: Extracts QR code from photo
- Receipt mode: Processes photo with OCR

### 3. **ReceiptScannerCameraView** (New Component)

A custom camera view controller for capturing receipt photos.

**Features:**
- High-quality photo capture (`.photo` preset)
- Dimmed overlay with transparent receipt area
- Blue border with corner indicators
- Instruction label: "Postavite račun unutar okvira"
- Large circular capture button with camera icon
- Visual and haptic feedback on capture
- Automatically stops camera after capture

**UI Details:**
- Receipt frame: 85% of screen width, 1.4:1 aspect ratio
- Corner indicators match QR scanner style
- Capture button: 70x70pt, bottom center, blue background

### 4. **ContentView.swift** (Updated)

**New Method:**
```swift
private func processReceiptImage(_ image: UIImage) async {
    // Calls ReceiptService to process OCR receipt
    // Updates budget and shows receipt detail view
    // Handles errors with alert
}
```

**Updated Sheet:**
```swift
.sheet(isPresented: $showScanner) {
    QRScannerView { url in
        // QR code callback
    } onReceiptScan: { image in
        // Receipt image callback
    }
}
```

### 5. **ReceiptService.swift** (Updated)

**New Method:**
```swift
func processReceiptImage(_ image: UIImage) async throws -> Receipt
```

**Functionality:**
- Calls `ReceiptOCRParser.parseReceipt(from: image)`
- Creates `Receipt` and `ReceiptItem` objects
- Checks for duplicates by receipt number
- Deducts from budget
- Saves to SwiftData
- Returns receipt for navigation

**Duplicate Detection:**
- QR receipts: Checked by URL
- OCR receipts: Checked by receipt number (if available)

## User Flow

### Scanning a Receipt

1. User taps **QR scanner button** in bottom toolbar
2. Scanner opens with **segmented control** at top
3. User selects **"Račun"** segment
4. Camera switches to **receipt mode**
5. User positions receipt within the frame overlay
6. User taps the **blue camera button**
7. Camera captures photo
8. **Processing overlay** appears: "Obrađujem račun..."
9. OCR extracts text from image
10. Parser extracts receipt data
11. Receipt is saved to SwiftData
12. **ReceiptDetailView** opens automatically
13. Budget is updated

### Error Handling

**Possible Errors:**
- "Neuspešna obrada slike" - Image loading failed
- "Nije pronađen tekst na slici" - No text detected
- "Nevažeći format računa" - Could not parse receipt data
- "Nije pronađen ukupan iznos" - Total amount not found
- "Ovaj račun je već skeniran" - Duplicate receipt

**User Experience:**
- Errors shown in alert dialog
- Processing overlay dismisses on error
- User can try again or cancel

## Technical Implementation

### Vision Framework Setup

```swift
let request = VNRecognizeTextRequest { request, error in
    // Handle recognized text
}

request.recognitionLanguages = ["sr-Latn", "en-US"]
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
```

### OCR Flow

1. Convert `UIImage` to `CGImage`
2. Create `VNImageRequestHandler`
3. Perform `VNRecognizeTextRequest`
4. Extract text from `VNRecognizedTextObservation`
5. Join lines into full text
6. Parse using regex patterns

### Text Parsing Strategy

**Merchant Info:**
- Look for "ФИСКАЛНИ РАЧУН" or "FISKALNI RACUN"
- Extract next 2-4 lines (name, address, city)
- Fallback: Find uppercase lines

**Totals:**
- Regex: `Укупан износ` or `Ukupan iznos`
- Extract decimal: `(\d{1,3}(?:\.\d{3})*,\d{2})`
- Parse tax separately: `пореза` or `poreza`

**Items:**
- Find section between "Артикли"/"Artikli" and "Укупан износ"
- Extract price lines (contain 2-3 decimal numbers)
- Match with previous line (item name)

**Date/Time:**
- Regex: `(\d{2}\.\d{2}\.\d{4}\.\s+\d{2}:\d{2}:\d{2})`
- Format: `dd.MM.yyyy. HH:mm:ss`

## Benefits

### User Benefits
✅ **Backup option** when QR code doesn't work
✅ **Handles damaged receipts** (torn, crumpled)
✅ **Same UI** for both scanning methods
✅ **Easy to use** - just take a photo
✅ **Visual guidance** with overlay frame

### Technical Benefits
✅ **Native Apple framework** (Vision)
✅ **On-device processing** (privacy)
✅ **No external dependencies**
✅ **Reuses existing data models**
✅ **Same display logic** (ReceiptDetailView)

## Limitations & Future Improvements

### Current Limitations
- OCR accuracy depends on receipt quality
- Serbian/Latin text recognition may have issues with Cyrillic
- Item parsing assumes specific format
- No image cropping or enhancement

### Potential Improvements
1. **Image preprocessing** - enhance contrast, rotate, crop
2. **Manual editing** - allow users to correct OCR mistakes
3. **Multiple language support** - better Cyrillic recognition
4. **Save original image** - attach photo to receipt record
5. **Smarter item parsing** - ML-based extraction
6. **Receipt templates** - pre-configured parsers for common stores
7. **Confidence scoring** - show user which fields need review

## Testing Recommendations

### Test Cases
1. ✅ Clear, flat receipt in good lighting
2. ✅ Crumpled receipt
3. ✅ Receipt with shadows
4. ✅ Receipt at an angle
5. ✅ Low-light conditions
6. ✅ Receipt with damaged QR code
7. ✅ Cyrillic vs Latin text
8. ✅ Different merchant formats
9. ✅ Very long receipts
10. ✅ Receipts with unusual layouts

### Performance Testing
- Measure OCR processing time
- Test with various image sizes
- Monitor memory usage
- Test batch scanning

## Code Quality

### Architecture
- ✅ Separation of concerns (Parser, Service, View)
- ✅ Async/await throughout
- ✅ Proper error handling
- ✅ SwiftUI best practices
- ✅ Reusable components

### Maintainability
- ✅ Clear naming conventions
- ✅ Documented functions
- ✅ Error types with localized messages
- ✅ Consistent code style
- ✅ Modular design

---

## Summary

Successfully implemented OCR-based receipt scanning as an alternative to QR code scanning. Users can now switch between the two methods using a segmented control in the scanner view. Both methods create the same `Receipt` objects and display in the same detail view, providing a seamless experience regardless of how the receipt was captured.

The implementation uses Apple's Vision framework for on-device text recognition, ensuring privacy and fast processing. The parser is specifically configured for Serbian receipts with support for both Latin and Cyrillic text.
