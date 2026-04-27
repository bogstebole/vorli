# Implementation Notes & Known Issues

## Implementation Summary

Successfully added OCR-based receipt scanning to the app. Users can now switch between QR code scanning and receipt photo scanning using a segmented control in the scanner view.

---

## Files Modified

### 1. **QRScannerView.swift**
- ✅ Added `ScanMode` enum (`.qrCode`, `.receipt`)
- ✅ Added segmented picker at top of view
- ✅ Added `onReceiptScan` callback parameter
- ✅ Added `isProcessing` state for loading overlay
- ✅ Created `ReceiptScannerCameraView` component
- ✅ Created `ReceiptScannerViewController` class
- ✅ Added photo library support for receipt mode
- ✅ Updated navigation title based on mode
- ✅ Added processing overlay with spinner

### 2. **ContentView.swift**
- ✅ Added `processReceiptImage(_:)` method
- ✅ Updated `showScanner` sheet to include `onReceiptScan` callback
- ✅ Connected receipt scanning to service layer

### 3. **ReceiptService.swift**
- ✅ Added `import UIKit`
- ✅ Created `processReceiptImage(_:)` method
- ✅ Added duplicate detection for OCR receipts (by receipt number)
- ✅ Integrated with OCR parser

## Files Created

### 1. **ReceiptOCRParser.swift**
- ✅ Uses Vision framework for text recognition
- ✅ Configured for Serbian (Latin) and English
- ✅ Parses merchant info, totals, items, dates
- ✅ Handles Serbian number format (1.234,56)
- ✅ Generates unique URLs for OCR receipts
- ✅ Returns `ParsedReceipt` (same as HTML parser)

---

## Technical Details

### Vision Framework Configuration

```swift
let request = VNRecognizeTextRequest()
request.recognitionLanguages = ["sr-Latn", "en-US"]
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
```

**Why these settings:**
- `sr-Latn`: Serbian Latin script (primary)
- `en-US`: English fallback (numbers, common words)
- `.accurate`: Higher quality but slower (acceptable for our use case)
- `usesLanguageCorrection`: Improves accuracy for known words

### Receipt Camera Setup

**Session Preset:** `.photo`
- Higher quality than `.high` or `.medium`
- Better for OCR text recognition
- Acceptable performance on modern devices

**Frame Overlay:**
- 85% screen width
- 1.4:1 aspect ratio (typical receipt)
- Dimmed background (50% black)
- Blue border with corner indicators
- Centered with instruction label

### OCR Processing Flow

1. User captures photo
2. Camera stops immediately
3. `isProcessing = true` → Shows overlay
4. Photo passed to `handleReceiptCapture(_:)`
5. `ReceiptOCRParser.parseReceipt(from:)` called
6. Vision performs OCR (async)
7. Text parsed using regex patterns
8. `ParsedReceipt` created
9. Passed to `ReceiptService.processReceiptImage(_:)`
10. Saved to SwiftData
11. `isProcessing = false` → Overlay dismissed
12. Sheet dismissed, detail view opens

---

## Known Issues & Limitations

### 1. OCR Accuracy
**Issue:** Not all receipts will be parsed correctly
**Causes:**
- Poor lighting conditions
- Blurry photos
- Unusual receipt formats
- Cyrillic text (configured for Latin)
- Faded or damaged receipts

**Mitigation:**
- Visual guide frame helps users position receipt
- Instruction label guides proper positioning
- Photo library fallback allows retrying
- Error messages guide user to retry

**Future Fix:**
- Add image preprocessing (contrast, sharpness)
- Allow manual correction of parsed data
- Show confidence scores for fields

### 2. Item Parsing Complexity
**Issue:** Line items may not always parse correctly
**Causes:**
- Item names spanning multiple lines
- Unusual price formatting
- Missing quantity information
- Extra descriptive text

**Current Behavior:**
- Returns items array (may be empty)
- Does not fail parsing if items missing
- Totals still extracted correctly

**Future Fix:**
- Improve regex patterns
- Use ML model for item detection
- Allow manual item entry

### 3. Date Parsing
**Issue:** May fallback to current date
**Causes:**
- Date format variations
- OCR misreading numbers
- Unexpected timestamp placement

**Current Behavior:**
- Logs warning: "⚠️ Could not parse timestamp, using current date"
- Uses `Date()` as fallback
- Receipt still saves successfully

**Future Fix:**
- Multiple date format patterns
- Better regex matching
- User notification when fallback used

### 4. Duplicate Detection
**Issue:** OCR receipts harder to detect duplicates
**Why:**
- QR receipts: Checked by unique URL
- OCR receipts: Checked by receipt number
- Receipt number may not be extracted

**Current Behavior:**
- If receipt number missing, duplicate check skipped
- User could add same receipt twice

**Future Fix:**
- Check by combination of merchant + total + date
- Fuzzy matching for similar receipts
- Show warning for likely duplicates

### 5. Camera Permissions
**Issue:** Shared with QR scanner
**Current Behavior:**
- Both modes use same camera permission
- If denied, both modes show error
- User directed to settings

**Not an issue:** Works as expected

### 6. Processing Time
**Issue:** OCR can take 2-5 seconds
**Current Behavior:**
- Shows "Obrađujem račun..." overlay
- User cannot interact during processing
- May feel slow for complex receipts

**Future Fix:**
- Optimize image size before OCR
- Show progress percentage
- Allow cancellation

### 7. Memory Usage
**Issue:** High-res photos can use significant memory
**Causes:**
- `.photo` preset captures high resolution
- Image kept in memory during processing
- Multiple observations from Vision

**Current Behavior:**
- Should handle normally on modern devices
- Image released after processing

**Future Fix:**
- Resize image before processing
- Monitor memory in testing
- Add memory warnings

---

## Testing Checklist

### Basic Functionality
- [ ] Segmented control switches modes
- [ ] Camera shows correct view for each mode
- [ ] Capture button works
- [ ] Processing overlay appears/disappears
- [ ] Receipt saves to database
- [ ] Detail view opens
- [ ] Budget updates correctly

### QR Code Mode
- [ ] QR scanner still works
- [ ] Auto-detection works
- [ ] Vibration feedback
- [ ] Photo library QR extraction
- [ ] Reticle visible

### Receipt Mode
- [ ] Camera starts in receipt mode
- [ ] Frame overlay visible
- [ ] Capture button visible and clickable
- [ ] Photo captured successfully
- [ ] OCR processes image
- [ ] Photo library selection works

### Error Handling
- [ ] Camera permission denied → Settings prompt
- [ ] OCR fails → Error alert shown
- [ ] No text found → Appropriate error
- [ ] Invalid receipt → Error message
- [ ] Duplicate receipt → Prevented
- [ ] Network error (QR mode) → Handled

### Edge Cases
- [ ] Very long receipts
- [ ] Very short receipts
- [ ] Receipts with only Cyrillic text
- [ ] Receipts at angles
- [ ] Dark/low-light photos
- [ ] Blurry photos
- [ ] Multiple receipts in frame
- [ ] Non-receipt photos
- [ ] Screenshots of receipts

### Performance
- [ ] No memory leaks
- [ ] Camera stops when view dismissed
- [ ] Fast switching between modes
- [ ] Reasonable processing time (<5s)
- [ ] No UI freezing during OCR

### UI/UX
- [ ] Segmented control visible and styled
- [ ] Frame overlay properly sized
- [ ] Instruction text readable
- [ ] Capture button accessible
- [ ] Processing overlay centered
- [ ] Error alerts clear
- [ ] Navigation smooth

---

## Performance Metrics

**Target Metrics:**
- OCR processing: < 5 seconds
- Camera start time: < 1 second
- Mode switching: Instant
- Memory usage: < 100 MB during processing

**Actual Performance:** (To be measured)
- OCR processing: TBD
- Camera start: TBD
- Mode switching: TBD
- Memory usage: TBD

---

## Future Enhancements

### High Priority
1. **Manual Editing** - Allow users to edit OCR results before saving
2. **Image Preprocessing** - Auto-rotate, crop, enhance contrast
3. **Better Error Messages** - More specific guidance

### Medium Priority
4. **Save Original Images** - Attach photos to receipt records
5. **Confidence Scores** - Show reliability of parsed fields
6. **Receipt Templates** - Store-specific parsing rules
7. **Batch Scanning** - Scan multiple receipts in sequence

### Low Priority
8. **Export Photos** - Share receipt images
9. **Search Receipts by Image** - Visual search
10. **Receipt Categories** - Auto-categorize by merchant
11. **Spending Insights** - ML-based recommendations

---

## Dependencies

### Frameworks Used
- ✅ **Vision** - Text recognition (OCR)
- ✅ **AVFoundation** - Camera capture
- ✅ **PhotosUI** - Photo library access
- ✅ **SwiftUI** - UI components
- ✅ **SwiftData** - Data persistence
- ✅ **UIKit** - UIImage, camera controllers

### No External Dependencies
- ✅ All Apple frameworks
- ✅ No third-party packages
- ✅ No CocoaPods/SPM dependencies
- ✅ No cloud services required

---

## Privacy Considerations

### Data Processing
- ✅ All OCR happens on-device
- ✅ No receipt data sent to servers
- ✅ No analytics collected
- ✅ Images processed in memory only
- ✅ No permanent image storage (yet)

### Permissions Required
- ✅ Camera (already requested for QR)
- ✅ Photo Library (already requested)
- ❌ No location tracking
- ❌ No network access for OCR

### Privacy.plist Entries
Existing entries should cover:
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`

---

## Deployment Notes

### Minimum iOS Version
- Vision framework: iOS 13+
- Current app target: Should already support this
- No changes needed

### Build Settings
- No special flags required
- No additional capabilities needed
- Standard camera/photos entitlements

### Testing Devices
Recommend testing on:
- iPhone SE (older/slower device)
- iPhone 14 Pro (newer/faster device)
- iPad (different aspect ratio)
- Various iOS versions (15, 16, 17)

### App Store Submission
- Update app description to mention receipt scanning
- Add screenshots showing both modes
- Mention OCR in privacy details
- No special review considerations

---

## Code Quality Notes

### Strengths
✅ **Clear separation** - Parser, Service, View are distinct
✅ **Error handling** - Proper error types with localized messages
✅ **Async/await** - Modern concurrency throughout
✅ **Reusability** - `ParsedReceipt` used by both parsers
✅ **SwiftUI best practices** - State management, bindings
✅ **Documentation** - Functions and complex logic documented

### Areas for Improvement
⚠️ **Limited test coverage** - No unit tests yet
⚠️ **Hardcoded strings** - Some text not localized
⚠️ **Magic numbers** - Frame sizes, timeouts could be constants
⚠️ **Error recovery** - Could retry failed OCR attempts
⚠️ **Logging** - Add more detailed logging for debugging

---

## Support & Maintenance

### Common User Questions

**Q: Why is photo scan slower than QR?**
A: OCR requires processing the entire image and extracting text. QR codes are instant because they contain pre-encoded data.

**Q: Why didn't my receipt scan correctly?**
A: Try improving lighting, flattening the receipt, and ensuring the entire receipt is visible in the frame.

**Q: Can I scan receipts in Cyrillic?**
A: The current implementation is optimized for Latin text. Cyrillic may have lower accuracy.

**Q: Does this work offline?**
A: Yes! OCR happens entirely on your device. QR scanning requires internet to fetch the receipt HTML.

**Q: Will this drain my battery?**
A: Camera and OCR do use more battery than normal app use, but it's minimal for occasional scanning.

### Debugging Tips

**Enable detailed logging:**
```swift
// In ReceiptOCRParser.swift, uncomment debug prints
print("📄 OCR Extracted \(lines.count) lines")
print("✅ Parsed \(items.count) items")
```

**Test OCR directly:**
```swift
let image = UIImage(named: "test_receipt")!
let parsed = try await ReceiptOCRParser.parseReceipt(from: image)
print(parsed)
```

**Check Vision availability:**
```swift
import Vision
print("Vision available: \(VNRecognizeTextRequest.self)")
```

---

## Changelog

### v1.0 - Initial Implementation
- ✅ Added OCR receipt scanning
- ✅ Segmented control for mode switching
- ✅ Receipt camera view with overlay
- ✅ Vision-based text recognition
- ✅ Serbian receipt parsing
- ✅ Photo library support
- ✅ Processing overlay
- ✅ Error handling
- ✅ Duplicate detection
- ✅ Budget integration

---

**Implementation Status:** ✅ Complete and Ready for Testing

**Next Steps:**
1. Build and run on device
2. Test both QR and receipt modes
3. Try various receipt types
4. Document any bugs found
5. Iterate based on user feedback
