# ScanSpend - Parser & SwiftData Implementation

## 🎯 Overview

This is the **data layer** implementation for ScanSpend, featuring:
- ✅ **SwiftData models** for receipts, items, and budget
- ✅ **HTML parser** for Serbian fiscal receipts (suf.purs.gov.rs)
- ✅ **Service layer** for managing receipts and budget
- ✅ **Working test interface** to verify parsing

## 📦 Files Created

### Models (`Receipt.swift`)
```swift
@Model class Receipt
@Model class ReceiptItem  
@Model class Budget
```

**Features:**
- Full relationship mapping (Receipt ↔ ReceiptItem)
- Cascade delete rules
- Serbian-specific fields (merchant, city, payment method)

### Parser (`ReceiptParser.swift`)

**Parses:**
- ✅ Merchant name, address, and city
- ✅ Line items (name, quantity, unit price, total)
- ✅ Total amount and tax
- ✅ Payment method
- ✅ Receipt number and cash register
- ✅ Timestamp (Serbian date format: DD.MM.YYYY. HH:mm:ss)

**Key Features:**
- Async/await networking
- Serbian number format support (1.234,56)
- Robust error handling
- URL validation

### Service (`ReceiptService.swift`)

**Provides:**
- `processReceipt(from:)` - Parse and save receipt
- `getBudget()` - Get or create budget
- `updateBudget(newBalance:)` - Update balance
- `fetchAllReceipts()` - Get all receipts
- `deleteReceipt(_:)` - Delete and refund

**Features:**
- Duplicate detection
- Automatic budget deduction
- Refunds on delete

### Extensions (`Extensions.swift`)

**Helpful utilities:**
- `Decimal.asRSD` - Format as Serbian currency
- `String.isSerbianFiscalURL` - URL validation
- `Date.asSerbianDateTime` - Serbian date formatting

## 🧪 Testing the Parser

### Current Test Interface

Run the app and tap **"Test Parser"** to parse the sample receipt URL. You'll see:
- Current balance (starts at 0)
- Receipt added to list
- Balance deducted automatically

### Parsing Your Own Receipts

Replace the `testURL` in `ContentView.swift`:

```swift
private let testURL = "YOUR_RECEIPT_URL_HERE"
```

## 📊 Data Structure

```
Budget
├─ currentBalance: Decimal
└─ lastUpdated: Date

Receipt
├─ merchantName: String
├─ merchantAddress: String
├─ merchantCity: String
├─ timestamp: Date
├─ totalAmount: Decimal
├─ totalTax: Decimal
├─ paymentMethod: String
├─ receiptNumber: String
└─ items: [ReceiptItem] ↓

ReceiptItem
├─ name: String
├─ quantity: Double
├─ unitPrice: Decimal
└─ lineTotal: Decimal
```

## 🔍 Parser Logic Explained

The parser works by:

1. **Fetching HTML** via URLSession
2. **Extracting `<pre>` content** (the monospace receipt text)
3. **Line-by-line parsing** using pattern matching:
   - Merchant: First non-numeric lines after header
   - Items: Lines with 3 numeric values (price, qty, total)
   - Totals: Lines containing "Укупан износ:"
   - Timestamp: Line with "ПФР време:"

4. **Serbian number format conversion**: `1.234,56` → `Decimal`

### Example Parsing Flow

```
Input: "       620,00          1          620,00"
       ↓ Split by whitespace
       ["620,00", "1", "620,00"]
       ↓ Parse each
       [Decimal(620), Double(1), Decimal(620)]
       ↓ Create ReceiptItem
       ReceiptItem(name: "Chicken cheese fries", ...)
```

## 🚀 Next Steps

Now that the data layer works, you can:

### 1. **Add QR Scanner**
```swift
// Use VisionKit or AVFoundation
import VisionKit

struct ScannerView: View {
    @State private var scanResult: String?
    
    var body: some View {
        DataScannerViewController(...)
    }
}
```

### 2. **Build Liquid Glass UI**
Replace the test interface with your beautiful glassmorphism design:

```swift
VStack {
    // Glass balance card
    Text(budget.currentBalance.asRSD)
        .font(.system(.largeTitle, design: .monospaced))
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
}
```

### 3. **Add Receipt Detail View**
Show individual items, tax breakdown, etc.

### 4. **Implement Budget Settings**
Let users set their monthly budget/balance.

## 🐛 Known Considerations

- **Merchant parsing**: Works best when merchant name is in UPPERCASE
- **Line items**: Assumes format `Name` on one line, then `Price Qty Total` on next
- **Network required**: Parser needs internet to fetch receipt HTML
- **URL structure**: Assumes suf.purs.gov.rs structure remains stable

## 🧰 Testing Different Receipts

To test edge cases, try receipts with:
- Different merchants
- Various item counts
- Cash vs card payments
- Different date formats

The parser should handle most variations, but you may need to tweak regex patterns for unusual formats.

## 💡 Tips for UI Implementation

When building the Liquid Glass UI:

1. **Use SF Mono everywhere**
   ```swift
   .font(.system(.body, design: .monospaced))
   ```

2. **Glass cards for receipts**
   ```swift
   GlassEffectContainer(spacing: 20) {
       ForEach(receipts) { receipt in
           ReceiptCard(receipt: receipt)
               .glassEffect()
       }
   }
   ```

3. **Interactive buttons**
   ```swift
   Button("Scan") { }
       .buttonStyle(.glass)
   ```

4. **Balance indicator colors**
   ```swift
   .foregroundStyle(budget >= 0 ? .green : .red)
   ```

---

**Ready to build the UI?** The data layer is solid and tested. Time to make it beautiful! 🎨
