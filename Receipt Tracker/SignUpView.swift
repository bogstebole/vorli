//
//  SignUpView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 22. 12. 2025.
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
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
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(.plain)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Confirm Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    SecureField("Confirm your password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Password Requirements
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password must be at least 6 characters")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Sign Up Button
                Button {
                    Task {
                        await signUp()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Text("Create Account")
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(!isFormValid || isLoading)
                .opacity((!isFormValid || isLoading) ? 0.6 : 1.0)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .navigationTitle("Create Account")
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
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    // MARK: - Methods
    
    private func signUp() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await authManager.signUp(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    SignUpView()
        .environment(AuthenticationManager())
}
