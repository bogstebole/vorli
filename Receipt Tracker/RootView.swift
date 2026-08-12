//
//  RootView.swift
//  Receipt Tracker
//
//  Hosts the native iOS 26 Liquid Glass tab bar: four switchable tabs in the
//  pill, and Skeniraj as the detached trailing circle beside it (the `.search`
//  role slot — the same "pill + gap + circle" the Phone app uses).
//
//  Skeniraj is a real destination, not an action dressed up as one. It used to
//  be an action: tapping it let the selection land on `.scan` and then put it
//  back on `.home`, with the scanner presented over Home as a full screen
//  cover. That round trip tears Home's hosting controller down and rebuilds it
//  mid-switch, and the rebuilt navigation stack loses the navigation bar's
//  inset — after which every pushed screen, every receipt and not just a
//  freshly scanned one, laid out ~115pt too high with its header behind the
//  bar, and stayed that way until the app was restarted. Refusing the selection
//  write instead just left TabView parked on a tab with empty content: a blank
//  screen with nothing but the tab bar. There is no third way out, so the tab
//  now holds the scanner itself and selecting it is an ordinary tab switch.
//

import SwiftUI
import SwiftData

enum RootTab: Hashable {
    case home, dashboard, planiranje, pretraga, scan
}

/// Shared navigation state. The Dashboard tab jumps Home to a chosen month,
/// and the scan tab hands its results to Home's navigation stack.
@Observable
final class AppNavigation {
    var selectedTab: RootTab = .home
    var selectedMonth: Date = Date()
    /// Set by the scan tab, consumed by Home's `navigationDestination`.
    var scannedReceipt: Receipt?
    /// An OCR result awaiting confirmation, consumed by Home's confirm sheet.
    var pendingReceipt: ParsedReceipt?
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var nav = AppNavigation()

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.selectedTab) {
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

            // Detached trailing circle. `.search` role gives that shape
            // natively; nothing else does.
            Tab("Skeniraj", image: "tab-scan", value: RootTab.scan, role: .search) {
                QRScannerView { url in
                    await processScannedReceipt(from: url)
                } onReceiptParsed: { parsed in
                    nav.pendingReceipt = parsed
                    nav.selectedTab = .home
                } onClose: {
                    nav.selectedTab = .home
                }
                // The camera wants the whole screen, and the X is the only way
                // out that makes sense mid-scan anyway.
                .toolbar(.hidden, for: .tabBar)
            }
        }
        // Icons only, no labels.
        .labelStyle(.iconOnly)
        // Monochrome selection — no Apple blue on the active tab.
        .tint(.primary)
        .environment(nav)
    }

    /// Runs while the scan tab is still on screen. Returns nil once the detail
    /// screen is in place in Home's stack, so switching to Home reveals a
    /// finished screen instead of racing a push against the switch. On failure
    /// the message goes back to the scanner, which shows it without leaving so
    /// the user can line the code up again.
    private func processScannedReceipt(from urlString: String) async -> String? {
        do {
            let service = ReceiptService(modelContext: modelContext)
            let receipt = try await service.processReceipt(from: urlString)
            // Unanimated: this push happens on a tab that is not on screen, so
            // there is no transition to see, and an animated one would still be
            // in flight when the tab switch lands on top of it.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                nav.scannedReceipt = receipt
            }
            // Let that settle before the scanner hands control back.
            await Task.yield()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self, FixedCost.self, Wish.self, MerchantCategory.self], inMemory: true)
        .environment(PremiumStore())
}
