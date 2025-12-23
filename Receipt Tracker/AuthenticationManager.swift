//
//  AuthenticationManager.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 22. 12. 2025.
//

import Foundation
import FirebaseAuth

@MainActor
@Observable
class AuthenticationManager {
    var user: User?
    var isAuthenticated: Bool {
        user != nil
    }
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    init() {
        registerAuthStateHandler()
    }
    
    deinit {
        if let authStateHandler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(authStateHandler)
        }
    }
    
    // MARK: - Auth State Monitoring
    
    private func registerAuthStateHandler() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String) async throws {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        user = authResult.user
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        user = authResult.user
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        try Auth.auth().signOut()
        user = nil
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.noUserLoggedIn
        }
        try await user.delete()
        self.user = nil
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noUserLoggedIn
    
    var errorDescription: String? {
        switch self {
        case .noUserLoggedIn:
            return "No user is currently logged in"
        }
    }
}
