//
//  SettingsSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 22. 12. 2025.
//

import SwiftUI
// COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
// import FirebaseAuth

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
    // @Environment(AuthenticationManager.self) private var authManager
    
    // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
    // @State private var showSignOutConfirmation = false
    // @State private var showDeleteAccountConfirmation = false
    // @State private var errorMessage: String?
    // @State private var showError = false
    
    var body: some View {
        NavigationStack {
            List {
                // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
                /*
                // Account Section
                Section {
                    if let user = authManager.user {
                        HStack {
                            Text("Email")
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(user.email ?? "No email")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("User ID")
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(user.uid.prefix(8) + "...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("Account")
                        .font(.system(.caption, design: .monospaced))
                }
                
                // Actions Section
                Section {
                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    Button(role: .destructive) {
                        showDeleteAccountConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Account")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                } header: {
                    Text("Actions")
                        .font(.system(.caption, design: .monospaced))
                }
                */
                
                // Placeholder for first release
                Section {
                    Text("Podešavanja uskoro")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Podešavanja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Gotovo") {
                        dismiss()
                    }
                }
            }
            // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
            /*
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .confirmationDialog("Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            */
        }
    }
    
    // MARK: - Methods
    
    // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
    /*
    private func signOut() {
        do {
            try authManager.signOut()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func deleteAccount() async {
        do {
            try await authManager.deleteAccount()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    */
}

// COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
/*
#Preview {
    SettingsSheet()
        .environment(AuthenticationManager())
}
*/
