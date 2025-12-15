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
    @Query(sort: \Receipt.timestamp, order: .reverse) private var receipts: [Receipt]
    @State private var budget: Budget?
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showScanner = false
    
    // Test URL - replace with your actual scanned URL
    private let testURL = "https://suf.purs.gov.rs/v/?vl=AzRUOUpOOVZHNFQ5Sk45VkcWxgAA7qwAABCHPQgAAAAAAAABmqbMEogAAABdMzXT8/YZwZB1Ik5vOgoMg+PdpM6Ylru25/vnBD5zKf1ZV/d6qah8NlQf1kEzXglOqc5y7A/37F6E3UO5xPMCKMAg5/tWDRubiMaDaPLK9Fv/DXY6ED/H4TY2pi0sacHTUB30WXX1R5bqQ+4TExniiQRq5CyPFRVrJkBqaP7TEasM6rgFnYNzhKyLljOMa6xHkS3LwqQMIqKvSwuxw3qR3y71b2mOaxrwSC1wN0pDVRfVt7HB1XWEOaK6qOgJw/N5tfRXu6wiiBW/WgIzF364QMUu4vHW3JidwUpxkNcsyuOHboXIk/Q8x1BN1b5SxezE98ycxbhbj2Wicmg+bJVwPdo7vqpM0q7oIyt8gx4N37B0FYi7iYJ0gIXIO9AppmffqmpNSrmZp+aT+SkROHwOIVYIUytcCytaxr3imSlpcTp/BLdhlgugEZ54nNK9eAwfx/PnfwBk8tTSqLj/d0z+HP6H2zeGKQh9qgIfqQSuavmOCuGQqQr4vCHHdwVD6rnCSu56Dw3yscp0+vnexhXenDMvyrVqCrjUDFFTiP068pV4BbW7QCaZPJb3HGW/SI9MgOf/GycOetfEsJyyrPMaVhSKXFBMQBpwo5ggtSy07XxpiULpBf/jExtPtHQc+Gj66duVN99i+G7805twEA7+1SYq2rHB6l6OCks9Cdm21uT5/xKFZJ6UZeibOht1cv4%3D"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Budget Display
                if let budget = budget {
                    VStack(spacing: 8) {
                        Text("Current Balance")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text(formatCurrency(budget.currentBalance))
                            .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                            .foregroundStyle(budget.currentBalance >= 0 ? .green : .red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Scan QR Code Button
                    Button {
                        showScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan Receipt")
                                .font(.system(.body, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    
                    // Test Parser Button (for debugging)
                    Button {
                        Task {
                            await processReceipt(from: testURL)
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "hammer")
                            }
                            Text("Test")
                                .font(.system(.body, design: .monospaced))
                        }
                        .frame(width: 100)
                        .padding()
                        .background(Color.gray.gradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(isProcessing)
                }
                
                // Receipts List
                List {
                    ForEach(receipts) { receipt in
                        NavigationLink {
                            ReceiptDetailView(receipt: receipt)
                        } label: {
                            ReceiptRowView(receipt: receipt)
                        }
                    }
                    .onDelete(perform: deleteReceipts)
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("ScanSpend")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
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
        }
        .task {
            loadBudget()
        }
    }
    
    private func loadBudget() {
        let service = ReceiptService(modelContext: modelContext)
        if let fetchedBudget = try? service.getBudget() {
            budget = fetchedBudget
        }
    }
    
    private func processReceipt(from urlString: String) async {
        isProcessing = true
        errorMessage = nil
        
        do {
            let service = ReceiptService(modelContext: modelContext)
            _ = try await service.processReceipt(from: urlString)
            
            // Reload budget
            loadBudget()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isProcessing = false
    }
    
    private func deleteReceipts(offsets: IndexSet) {
        let service = ReceiptService(modelContext: modelContext)
        
        for index in offsets {
            let receipt = receipts[index]
            try? service.deleteReceipt(receipt)
        }
        
        loadBudget()
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RSD"
        formatter.locale = Locale(identifier: "sr_RS")
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }
}

// MARK: - Receipt Row View

struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Merchant and Amount
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(receipt.merchantName)
                        .font(.system(.headline, design: .monospaced))
                        .lineLimit(1)
                    
                    if !receipt.merchantCity.isEmpty {
                        Text(receipt.merchantCity)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Text(formatCurrency(receipt.totalAmount))
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(.red)
            }
            
            // Date and Article Count
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(receipt.timestamp, style: .date)
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.caption2)
                    Text("\(receipt.items.count) артикал\(receipt.items.count == 1 ? "" : "а")")
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
            
            // Sample items preview (first 2)
            if !receipt.items.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(receipt.items.prefix(2)) { item in
                        HStack(spacing: 6) {
                            Text("•")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.quaternary)
                            Text(item.name)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    
                    if receipt.items.count > 2 {
                        Text("... и још \(receipt.items.count - 2)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.quaternary)
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RSD"
        formatter.locale = Locale(identifier: "sr_RS")
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Receipt.self, Budget.self], inMemory: true)
}
