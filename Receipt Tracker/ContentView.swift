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
    @Query(sort: \Receipt.timestamp, order: .reverse) private var allReceipts: [Receipt]
    @State private var budget: Budget?
    
    @State private var selectedMonth: Date = Date()
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showScanner = false
    @State private var showAddBalance = false
    @State private var showDashboard = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Header
                CustomHeader()
                
                // Main Content - Scrollable
                ScrollView {
                    VStack(spacing: 20) {
                        // Month/Balance Card
                        if let budget = budget {
                            MonthBalanceCard(
                                month: currentMonthName,
                                currentBalance: budget.currentBalance,
                                spent: currentMonthSpent
                            )
                        }
                        
                        // Section Divider
                        SectionDivider(title: "Računi")
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
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
                            .padding(.bottom, 100) // Space for toolbar
                        }
                    }
                }
                
                // Bottom Toolbar
                CustomToolbar(
                    onAddBalance: {
                        showAddBalance = true
                    },
                    onFilter: {
                        // TODO: Implement filter
                        print("Filter tapped")
                    },
                    onDashboard: {
                        showDashboard = true
                    },
                    onScan: {
                        showScanner = true
                    }
                )
            }
            .navigationBarHidden(true)
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
            _ = try await service.processReceipt(from: urlString)
            loadBudget()
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
        if let currentBudget = budget {
            try? service.updateBudget(newBalance: currentBudget.currentBalance + amount)
            loadBudget()
        }
    }
}

// MARK: - Custom Header

struct CustomHeader: View {
    var body: some View {
        HStack {
            // Title
            Text("Receipts")
                .font(.system(.title3, design: .monospaced, weight: .regular))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Avatar Button
            Button {
                // TODO: Navigate to settings
                print("Settings tapped")
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Custom Toolbar

struct CustomToolbar: View {
    let onAddBalance: () -> Void
    let onFilter: () -> Void
    let onDashboard: () -> Void
    let onScan: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Left Button Group
            HStack(spacing: 12) {
                ToolbarButton(icon: "plus", color: .green, action: onAddBalance)
                ToolbarButton(icon: "line.3.horizontal.decrease.circle", color: .gray, action: onFilter)
                ToolbarButton(icon: "square.grid.2x2", color: .blue, action: onDashboard)
            }
            
            Spacer()
            
            // QR Scanner CTA
            Button(action: onScan) {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                    
                    Text("Scan")
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.blue.gradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.tertiary),
            alignment: .top
        )
    }
}

struct ToolbarButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())
        }
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
        .modelContainer(for: [Receipt.self, Budget.self], inMemory: true)
}



#Preview {
    ContentView()
        .modelContainer(for: [Receipt.self, Budget.self], inMemory: true)
}
