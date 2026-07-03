// Debug-only screen — compiled out of release builds.
#if DEBUG
//
//  MainTabView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Receipts", systemImage: "receipt")
                }
            
            DebugParserView()
                .tabItem {
                    Label("Debug", systemImage: "hammer.fill")
                }
            
            ReceiptHTMLDebugView()
                .tabItem {
                    Label("HTML", systemImage: "doc.text")
                }
        }
    }
}

#Preview {
    MainTabView()
}
#endif
