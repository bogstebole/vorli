//
//  SettingsSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 22. 12. 2025.
//

import SwiftUI
import SwiftData
// COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
// import FirebaseAuth

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
    // @Environment(AuthenticationManager.self) private var authManager

    @State private var apiKey: String = UserDefaults.standard.string(forKey: VorliService.apiKeyDefaultsKey) ?? ""
    @State private var apiKeyVisible = false

    var body: some View {
        NavigationStack {
            List {
                // Vorli AI Section
                Section {
                    HStack {
                        if apiKeyVisible {
                            TextField("sk-ant-...", text: $apiKey)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: apiKey) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: VorliService.apiKeyDefaultsKey)
                                }
                        } else {
                            SecureField("sk-ant-...", text: $apiKey)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: apiKey) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: VorliService.apiKeyDefaultsKey)
                                }
                        }

                        Button {
                            apiKeyVisible.toggle()
                        } label: {
                            Image(systemName: apiKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Vorli AI — API ključ")
                        .font(.system(.caption, design: .monospaced))
                } footer: {
                    Text("Anthropic API ključ se čuva lokalno na uređaju. Nikad se ne šalje nigde osim direktno na api.anthropic.com.")
                        .font(.system(.caption2, design: .monospaced))
                }

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
