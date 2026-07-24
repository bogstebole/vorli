//
//  RootView.swift
//  Receipt Tracker
//
//  Hosts the native iOS 26 Liquid Glass tab bar: Početna + Pregled as
//  switchable tabs, and Skeniraj as a detached trailing action (the
//  `.search` role slot — the same "pill + gap + circle" the Phone app uses).
//  Tapping Skeniraj is an action, not a destination: it flips back to Home
//  and presents the scanner there, so the scan → confirm → detail flow stays
//  inside Home's navigation stack.
//

import SwiftUI
import SwiftData

enum RootTab: Hashable {
    case home, dashboard, planiranje, pretraga, scan
}

/// Shared navigation state so the Dashboard tab can jump Home to a chosen
/// month, and the tab bar can trigger the scanner living inside Home.
@Observable
final class AppNavigation {
    var selectedTab: RootTab = .home
    var selectedMonth: Date = Date()
    var showScanner: Bool = false
}

struct RootView: View {
    @State private var nav = AppNavigation()

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.selectedTab) {
            Tab("Početna", systemImage: "house", value: RootTab.home) {
                ContentView()
            }

            Tab("Pregled", systemImage: "square.grid.2x2", value: RootTab.dashboard) {
                DashboardView()
            }

            Tab("Planiranje", systemImage: "list.bullet.clipboard", value: RootTab.planiranje) {
                PlaniranjeView()
            }

            // Global search — its own stack since SearchView relies on a
            // navigation title/toolbar (it used to be a pushed destination).
            Tab("Pretraga", systemImage: "magnifyingglass", value: RootTab.pretraga) {
                NavigationStack { SearchView() }
            }

            // Detached trailing action. `.search` role gives the native
            // separated circle; we never actually stay on it.
            Tab("Skeniraj", systemImage: "qrcode.viewfinder", value: RootTab.scan, role: .search) {
                Color.clear
            }
        }
        // Icons only, no labels.
        .labelStyle(.iconOnly)
        // Monochrome selection — no Apple blue on the active tab.
        .tint(.primary)
        .environment(nav)
        .onChange(of: nav.selectedTab) { _, newValue in
            guard newValue == .scan else { return }
            nav.selectedTab = .home
            nav.showScanner = true
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self, FixedCost.self, Wish.self, MerchantCategory.self], inMemory: true)
        .environment(PremiumStore())
}
