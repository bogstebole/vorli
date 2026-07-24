//
//  Receipt_TrackerApp.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import SwiftData

@main
struct Receipt_TrackerApp: App {
    @State private var premiumStore = PremiumStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Receipt.self,
            ReceiptItem.self,
            Budget.self,
            BudgetEntry.self,
            SavingsGoal.self,
            FixedCost.self,
            Wish.self,
            MerchantCategory.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(sharedModelContainer)
                .environment(premiumStore)
        }
    }
}
