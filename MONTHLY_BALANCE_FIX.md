# Monthly Balance Dashboard Fix

## Problem Summary
The monthly tiles in the dashboard were not displaying realistic data because:
1. Only one global `Budget` object existed with a single `currentBalance`
2. No historical tracking of when balance was added
3. The `calculateLeftOverBalance` method always returned 0

## Solution Implemented

### 1. New Data Model: `BudgetEntry`
Created a new SwiftData model to track each time balance is added:

```swift
@Model
final class BudgetEntry {
    var id: UUID
    var amount: Decimal
    var timestamp: Date
    var note: String
}
```

**Purpose**: Each time you manually add balance, a `BudgetEntry` is created with the amount and timestamp. This gives us historical data to calculate monthly balances.

### 2. Updated Service Layer
Modified `ReceiptService.swift` to:
- Create a `BudgetEntry` whenever balance is added via `addBalanceEntry(amount:)`
- Provide `fetchBudgetEntries()` to retrieve all budget entries

### 3. Updated Dashboard Calculation Logic
The `DashboardSheet` now:
- Loads all `BudgetEntry` records on appear
- Calculates leftover balance per month using this formula:

```
Leftover Balance = (Budget Added in Month) - (Spent in Month)
```

**Example**:
- January: You add 50,000 RSD → Scan receipts totaling 20,000 RSD
  - Leftover Balance: 50,000 - 20,000 = 30,000 RSD
  - Spent: 20,000 RSD

- February: You add 60,000 RSD → Scan receipts totaling 35,000 RSD
  - Leftover Balance: 60,000 - 35,000 = 25,000 RSD
  - Spent: 35,000 RSD

Each month is independent and shows its own data!

### 4. Updated App Configuration
Added `BudgetEntry` to the SwiftData schema in:
- `Receipt_TrackerApp.swift` (main app container)
- `ContentView.swift` (preview)

## How It Works Now

### When You Add Balance:
1. User taps "+" button → enters amount (e.g., 50,000 RSD)
2. `ReceiptService.addBalanceEntry(amount:)` is called
3. Global `Budget.currentBalance` increases by 50,000
4. New `BudgetEntry` created with amount=50,000 and timestamp=now

### When You Scan a Receipt:
1. User scans receipt → total is 5,000 RSD
2. `ReceiptService.deductFromBudget(amount:)` is called
3. Global `Budget.currentBalance` decreases by 5,000
4. Receipt is saved with timestamp

### In the Dashboard:
1. For each month (Jan-Dec):
   - Get all receipts for that month → calculate total spent
   - Get all budget entries for that month → calculate total added
   - Leftover = Added - Spent
2. Display in monthly tiles with proper visualization

## Migration Notes

**Existing Users**: If you have existing data, the app will work fine. However:
- Previous months won't have budget entries (since we just added this)
- Those months will show 0 leftover balance
- Going forward, all new balance additions will be tracked properly

**Fresh Install**: Everything will work perfectly from day one!

## Files Modified

1. **Receipt.swift**
   - Added `BudgetEntry` model

2. **ReceiptService.swift**
   - Added `addBalanceEntry(amount:)` method
   - Added `fetchBudgetEntries()` method

3. **ContentView.swift**
   - Updated `addBalance(_:)` to use new service method
   - Updated preview to include BudgetEntry

4. **DashboardSheet.swift**
   - Added `@Environment(\.modelContext)` to access database
   - Added `budgetEntries` state variable
   - Added `loadBudgetEntries()` method
   - Rewrote `calculateLeftOverBalance(for:spent:)` with proper logic
   - Added `.task` modifier to load data on appear

5. **Receipt_TrackerApp.swift**
   - Added `BudgetEntry.self` to schema

## Testing Recommendations

1. **Test New Month Flow**:
   - Add balance (e.g., 50,000 RSD) in current month
   - Scan a few receipts
   - Open dashboard → verify current month shows correct leftover and spent

2. **Test Multiple Months**:
   - Add balance in one month
   - Wait for next month (or change device date for testing)
   - Add different balance in new month
   - Scan receipts in both months
   - Verify each month shows independent data

3. **Test Edge Cases**:
   - Month with no budget added → should show 0 leftover
   - Month with no receipts → should show full added amount as leftover
   - Month with spent > added → leftover capped at 0 (no negative display)

## Future Enhancements

Potential improvements you could add:
1. Show "carried over" balance from previous months
2. Allow editing/deleting budget entries
3. Add budget entry notes/categories
4. Show year-over-year comparisons
5. Export monthly reports
