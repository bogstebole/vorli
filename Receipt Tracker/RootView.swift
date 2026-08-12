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
        TabView(selection: scanIsAnAction) {
            Tab("Početna", image: "tab-home", value: RootTab.home) {
                ContentView()
            }

            Tab("Pregled", image: "tab-pregled", value: RootTab.dashboard) {
                DashboardView()
            }

            Tab("Planiranje", image: "tab-planiranje", value: RootTab.planiranje) {
                PlaniranjeView()
            }

            // Global search — its own stack since SearchView relies on a
            // navigation title/toolbar (it used to be a pushed destination).
            Tab("Pretraga", image: "tab-pretraga", value: RootTab.pretraga) {
                NavigationStack { SearchView() }
            }

            // Detached trailing action. `.search` role gives the native
            // separated circle; the binding above makes sure we never actually
            // land on it, so this content is never seen.
            Tab("Skeniraj", image: "tab-scan", value: RootTab.scan, role: .search) {
                Color.clear
            }
        }
        // Icons only, no labels.
        .labelStyle(.iconOnly)
        // Monochrome selection — no Apple blue on the active tab.
        .tint(.primary)
        .environment(nav)
    }

    /// Scanning is an action, not a destination, so the Skeniraj tab is never
    /// allowed to become the selection — the write is swallowed and turned
    /// into "present the scanner over whatever tab you were on".
    ///
    /// This used to let the selection land on `.scan` and then set it back to
    /// `.home`. That round trip tears the home tab's hosting controller down
    /// and rebuilds it mid-switch, and the rebuilt navigation stack loses the
    /// navigation bar's inset: from then on every pushed screen — every
    /// receipt, not just a freshly scanned one — laid out ~115pt too high with
    /// its header behind the bar, and stayed that way until the app restarted.
    private var scanIsAnAction: Binding<RootTab> {
        Binding(
            get: { nav.selectedTab },
            set: { newValue in
                guard newValue != .scan else {
                    // Home, because the scan → confirm → detail flow lives in
                    // Home's navigation stack. Going there from another tab is
                    // an ordinary switch and harmless; it is only the trip
                    // through `.scan` that does the damage.
                    nav.selectedTab = .home
                    nav.showScanner = true
                    return
                }
                nav.selectedTab = newValue
            }
        )
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self, FixedCost.self, Wish.self, MerchantCategory.self], inMemory: true)
        .environment(PremiumStore())
}
