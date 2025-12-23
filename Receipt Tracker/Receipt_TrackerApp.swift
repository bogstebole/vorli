//
//  Receipt_TrackerApp.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import SwiftData
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct Receipt_TrackerApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var authManager: AuthenticationManager?
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Receipt.self,
            ReceiptItem.self,
            Budget.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Firebase is configured by AppDelegate first, then we can safely initialize AuthenticationManager
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let authManager = authManager {
                    if authManager.isAuthenticated {
                        ContentView()
                            .modelContainer(sharedModelContainer)
                            .environment(authManager)
                    } else {
                        LoginView()
                            .environment(authManager)
                    }
                } else {
                    // Show loading while initializing
                    ProgressView()
                }
            }
            .onAppear {
                if authManager == nil {
                    authManager = AuthenticationManager()
                }
            }
        }
    }
}
