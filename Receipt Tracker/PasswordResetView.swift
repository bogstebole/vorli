//
//  PasswordResetView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 22. 12. 2025.
//

import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Description
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(.plain)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(12)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Reset Button
                Button {
                    Task {
                        await resetPassword()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Text("Send Reset Link")
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(isLoading || email.isEmpty)
                .opacity((isLoading || email.isEmpty) ? 0.6 : 1.0)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Password reset link has been sent to \(email)")
            }
        }
    }
    
    // MARK: - Methods
    
    private func resetPassword() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await authManager.resetPassword(email: email)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    PasswordResetView()
        .environment(AuthenticationManager())
}
