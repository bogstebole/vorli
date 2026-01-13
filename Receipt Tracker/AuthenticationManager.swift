//
//  AuthenticationManager.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 22. 12. 2025.
//

// COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
/*
import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
@Observable
class AuthenticationManager: NSObject {
    var user: User?
    var isAuthenticated: Bool {
        user != nil
    }
    
    @ObservationIgnored
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    @ObservationIgnored
    private var currentNonce: String?
    
    override init() {
        super.init()
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
    
    // MARK: - Email/Password Sign Up
    
    func signUp(email: String, password: String) async throws {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        user = authResult.user
    }
    
    // MARK: - Email/Password Sign In
    
    func signIn(email: String, password: String) async throws {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        user = authResult.user
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidAppleCredentials
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        let authResult = try await Auth.auth().signIn(with: credential)
        user = authResult.user
    }
    
    func startSignInWithAppleFlow() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }
    
    // MARK: - Google Sign In
    // Note: Google Sign-In requires GoogleSignIn SDK
    // Add this method when you add Google Sign-In SDK
    /*
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        // Implementation requires GoogleSignIn SDK
    }
    */
    
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
    
    // MARK: - Helpers for Apple Sign In
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case noUserLoggedIn
    case invalidAppleCredentials
    
    var errorDescription: String? {
        switch self {
        case .noUserLoggedIn:
            return "No user is currently logged in"
        case .invalidAppleCredentials:
            return "Invalid Apple credentials"
        }
    }
}
*/
