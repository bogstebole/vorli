# Receipt Scanning - User Guide

## How to Scan a Receipt

### Method 1: QR Code (Existing)
1. Tap the **QR scanner icon** in the bottom toolbar
2. Select **"QR Kod"** in the segmented control (default)
3. Point camera at QR code on receipt
4. Wait for automatic detection (vibration confirms scan)
5. Receipt details appear automatically

### Method 2: Photo Scan (NEW!)
1. Tap the **QR scanner icon** in the bottom toolbar
2. Select **"Račun"** in the segmented control
3. Position the full receipt within the blue frame
4. Tap the **blue camera button** at bottom
5. Wait for "Obrađujem račun..." to finish
6. Receipt details appear automatically

---

## UI Layout

```
┌─────────────────────────────────────┐
│  ← Otkaži    Skeniraj račun    📷   │  Navigation bar
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │   QR Kod    │    Račun         │ │  Segmented control
│ └─────────────────────────────────┘ │
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │         █████████           │   │  Blue frame overlay
│  │         █ Receipt █         │   │  (Receipt mode only)
│  │         █  Photo  █         │   │
│  │         █████████           │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│   "Postavite račun unutar okvira"  │  Instruction label
│                                     │
│             ┌─────┐                 │
│             │  📷  │                 │  Capture button
│             └─────┘                 │  (Receipt mode only)
└─────────────────────────────────────┘
```

---

## When to Use Each Method

### Use QR Code When:
✅ QR code is intact and clearly visible
✅ You want the fastest scan (instant)
✅ You're in a well-lit environment
✅ The receipt is fresh from the store

### Use Photo Scan When:
✅ QR code is damaged, torn, or missing
✅ Receipt is crumpled or folded
✅ QR scanner isn't detecting the code
✅ You want to keep a backup copy
✅ Receipt is old or faded (but still readable)

---

## Tips for Best Results

### Photo Scanning Tips:
1. **Good Lighting** - Use natural light or bright indoor lighting
2. **Flat Surface** - Lay receipt on a table or hold it flat
3. **Fill the Frame** - Position receipt to fill most of the blue frame
4. **Avoid Shadows** - Don't block light with your hand
5. **Hold Steady** - Keep camera still when capturing
6. **Check Readability** - Make sure text is clear and not blurry

### Common Issues & Solutions:

**"Nije pronađen tekst na slici"**
- Improve lighting
- Clean camera lens
- Hold camera closer
- Make sure receipt is face-up

**"Nevažeći format računa"**
- Ensure entire receipt is visible
- Check that it's a Serbian fiscal receipt
- Try flattening crumpled receipt

**"Nije pronađen ukupan iznos"**
- Make sure bottom of receipt is visible
- Verify receipt isn't cut off in photo
- Check that text is clear and readable

**Processing takes too long**
- Receipt may be very long
- Wait a few more seconds
- If stuck, cancel and try again

---

## What Data is Extracted

Both QR and Photo scanning extract the same information:

✅ **Merchant Information**
   - Store name
   - Address
   - City

✅ **Receipt Details**
   - Date and time
   - Receipt number
   - Cash register number

✅ **Financial Information**
   - Total amount
   - Tax (PDV)
   - Payment method

✅ **Line Items**
   - Item name
   - Quantity
   - Unit price
   - Line total

---

## Privacy & Security

🔒 **Your receipts never leave your device**
- OCR processing happens entirely on your iPhone
- No data is sent to servers
- Receipt images are processed in memory
- Only extracted text data is saved

---

## Comparison

| Feature | QR Code | Photo Scan |
|---------|---------|------------|
| **Speed** | Instant | 2-5 seconds |
| **Accuracy** | 100% | 85-95% |
| **Works offline** | ✅ Yes (after QR scan) | ✅ Yes |
| **Damaged receipts** | ❌ No | ✅ Yes |
| **Manual capture** | ❌ Auto only | ✅ Button press |
| **Visual feedback** | Vibration | Loading screen |
| **Photo library** | ✅ Supported | ✅ Supported |

---

## Troubleshooting

### QR Code Won't Scan
1. Clean camera lens
2. Improve lighting
3. Flatten receipt
4. Try photo from library
5. **Switch to Receipt mode** ← NEW!

### Photo Scan Issues
1. Retake photo in better light
2. Hold camera steadier
3. Make sure entire receipt is visible
4. Clean camera lens
5. Try scanning smaller sections
6. Use photo library option

### Receipt Not Saving
1. Check internet connection (for QR mode)
2. Verify you have storage space
3. Check if receipt is duplicate
4. Review error message

---

## Advanced Features

### Photo Library Support
Both modes support importing from your photo library:
1. Tap the **📷 photo icon** in top-right
2. Select photo from library
3. App processes it based on current mode

### Duplicate Detection
- **QR Mode**: Checks URL
- **Photo Mode**: Checks receipt number
- Prevents same receipt being added twice

### Auto-Navigation
After successful scan, app automatically:
1. Saves receipt to database
2. Updates your budget
3. Opens receipt detail view
4. Shows all extracted information

---

## Coming Soon (Potential Features)

🔮 **Manual Editing** - Edit OCR results before saving
🔮 **Image Storage** - Keep original receipt photos
🔮 **Batch Scanning** - Scan multiple receipts at once
🔮 **Receipt Templates** - Pre-configured parsers for popular stores
🔮 **Confidence Scoring** - See which fields need review
🔮 **Export Photos** - Share receipt images

---

Enjoy your new receipt scanning feature! 📸✨
