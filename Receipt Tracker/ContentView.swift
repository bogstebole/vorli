//
//  ContentView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
    // @Environment(AuthenticationManager.self) private var authManager
    @Query(sort: \Receipt.timestamp, order: .reverse) private var allReceipts: [Receipt]
    @Query(sort: \BudgetEntry.timestamp, order: .reverse) private var budgetEntries: [BudgetEntry]
    @State private var budget: Budget?
    
    @State private var selectedMonth: Date = Date()
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showScanner = false
    @State private var showAddBalance = false
    @State private var showDashboard = false
    @State private var showSettings = false
    @State private var scannedReceipt: Receipt?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Header
                CustomHeader(showSettings: $showSettings)
                
                // Main Content - Scrollable
                ScrollView {
                    VStack(spacing: 12) {
                        // Month/Balance Card
                        if let budget = budget {
                            MonthBalanceCard(
                                month: currentMonthName,
                                currentBalance: currentMonthLeftoverBalance,
                                spent: currentMonthSpent,
                                spentToday: spentToday
                            )
                        }
                        
                        // Section Divider
                        SectionDivider(title: "Receipts")
                            .padding(.horizontal)
                        
                        // Receipt Cards
                        if filteredReceipts.isEmpty {
                            EmptyReceiptsView()
                                .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredReceipts) { receipt in
                                    NavigationLink {
                                        ReceiptDetailView(receipt: receipt)
                                    } label: {
                                        ReceiptCardView(receipt: receipt)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteReceipt(receipt)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20) // Reduced space since native toolbar handles this
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    // Leading group of actions
                    Button {
                        showAddBalance = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    
                    Button {
                        // TODO: Implement filter
                        print("Filter tapped")
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    
                    Button {
                        showDashboard = true
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    
                    Spacer()
                    
                    // Trailing scan action
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { url in
                    Task {
                        await processReceipt(from: url)
                    }
                }
            }
            .sheet(isPresented: $showAddBalance) {
                AddBalanceSheet { amount in
                    addBalance(amount)
                }
            }
            .sheet(isPresented: $showDashboard) {
                DashboardSheet(receipts: allReceipts) { month in
                    selectedMonth = month
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
                    // .environment(authManager)
            }
            .navigationDestination(item: $scannedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
        }
        .task {
            loadBudget()
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US") // Using English locale for Latin script
        return formatter.string(from: selectedMonth)
    }
    
    private var filteredReceipts: [Receipt] {
        let calendar = Calendar.current
        return allReceipts.filter { receipt in
            calendar.isDate(receipt.timestamp, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    private var currentMonthSpent: Decimal {
        filteredReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount }
    }
    
    private var currentMonthLeftoverBalance: Decimal {
        let calendar = Calendar.current
        
        // Get all budget entries for the selected month
        let monthBudgetEntries = budgetEntries.filter { entry in
            calendar.isDate(entry.timestamp, equalTo: selectedMonth, toGranularity: .month)
        }
        
        // Sum all budget entries added in this month
        let totalBudgetAdded = monthBudgetEntries.reduce(Decimal(0)) { $0 + $1.amount }
        
        // Leftover balance = budget added this month - spent this month
        let leftOver = totalBudgetAdded - currentMonthSpent
        
        return leftOver
    }
    
    private var spentToday: Decimal {
        let calendar = Calendar.current
        let today = Date()
        
        return allReceipts.filter { receipt in
            calendar.isDate(receipt.timestamp, inSameDayAs: today)
        }.reduce(Decimal(0)) { $0 + $1.totalAmount }
    }
    
    // MARK: - Methods
    
    private func loadBudget() {
        let service = ReceiptService(modelContext: modelContext)
        if let fetchedBudget = try? service.getBudget() {
            budget = fetchedBudget
        }
    }
    
    private func processReceipt(from urlString: String) async {
        do {
            let service = ReceiptService(modelContext: modelContext)
            let receipt = try await service.processReceipt(from: urlString)
            loadBudget()
            scannedReceipt = receipt
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func deleteReceipt(_ receipt: Receipt) {
        let service = ReceiptService(modelContext: modelContext)
        try? service.deleteReceipt(receipt)
        loadBudget()
    }
    
    private func addBalance(_ amount: Decimal) {
        let service = ReceiptService(modelContext: modelContext)
        try? service.addBalanceEntry(amount: amount)
        loadBudget()
    }
}

// MARK: - Custom Header

struct CustomHeader: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        HStack {
            // Title
            Text("Receipts")
                .font(.system(.title3, design: .monospaced, weight: .regular))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // COMMENTED OUT FOR FIRST RELEASE - NO SETTINGS/AUTHENTICATION
            /*
            // Avatar Button
            Button {
                showSettings = true
            } label: {
                Image("avatar") // Replace with your actual image asset name
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 27, height: 36)
                    .clipped()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.09), radius: 2.5, x: 0, y: 5)
                    .shadow(color: .black.opacity(0.05), radius: 3.5, x: 1, y: 12)
                    .shadow(color: .black.opacity(0.01), radius: 4, x: 1, y: 21)
                    .shadow(color: .black.opacity(0), radius: 4.5, x: 2, y: 33)
                    .rotationEffect(Angle(degrees: -5))
            }
            */
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Empty State

struct EmptyReceiptsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "receipt")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            
            Text("No receipts this month")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(.secondary)
            
            Text("Scan a QR code to add your first receipt")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self], inMemory: true)
}



#Preview {
    ContentView()
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self], inMemory: true)
}
