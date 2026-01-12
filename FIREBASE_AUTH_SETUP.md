# Firebase Authentication Setup Guide

**Complete guide for implementing Firebase Authentication in SwiftUI apps with Email/Password and Apple Sign-In support.**

> 💡 This guide is reusable for any SwiftUI project. All code examples are generic and can be adapted to your project structure.

---

## 📚 Table of Contents

1. [Quick Start](#quick-start)
2. [Firebase Console Setup](#firebase-console-setup)
3. [Xcode Project Setup](#xcode-project-setup)
4. [Implementation Files](#implementation-files)
5. [Apple Sign-In Setup](#apple-sign-in-setup)
6. [Testing & Troubleshooting](#testing--troubleshooting)
7. [Optional: Google Sign-In](#optional-google-sign-in)

---

## 🚀 Quick Start

### What This Guide Implements

✅ **Email/Password Authentication** - Sign up, sign in, password reset  
✅ **Apple Sign-In** - Native Sign in with Apple button  
✅ **Session Management** - Persistent user sessions across app launches  
✅ **Account Management** - Sign out and delete account  
❌ **Google Sign-In** - Not included (see optional section)

### Required Files

You'll need to create or modify these files in your project:

- `AuthenticationManager.swift` - Manages all authentication with Firebase
- `LoginView.swift` - Login screen with Email/Password and Apple Sign-In
- `SignUpView.swift` - Email/Password account creation
- `PasswordResetView.swift` - Password reset functionality
- `SettingsSheet.swift` - User settings with sign out and account deletion
- `YourApp.swift` - Firebase initialization on app launch

---

## 🔥 Firebase Console Setup

### Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Add project"** or select an existing project
3. Follow the setup wizard:
   - Enter project name
   - (Optional) Enable Google Analytics
   - Click **"Create project"**

### Step 2: Add iOS App to Firebase

1. In your Firebase project, click the **iOS icon** or **"Add app"** → **iOS**
2. Fill in the registration form:
   - **Bundle ID**: Get this from Xcode (Signing & Capabilities → Bundle Identifier)
   - **App nickname**: (Optional) e.g., "MyApp iOS"
   - **App Store ID**: (Optional, can skip for now)
3. Click **"Register app"**

### Step 3: Download GoogleService-Info.plist

1. Click **"Download GoogleService-Info.plist"**
2. **Important**: Keep this file safe, you'll add it to Xcode next
3. Click **"Next"** and **"Continue to console"**

### Step 4: Enable Authentication Providers

1. In the left sidebar, click **"Authentication"** (or Build → Authentication)
2. Click **"Get started"** if it's your first time
3. Click the **"Sign-in method"** tab
4. Enable the providers you want:

#### Email/Password:
- Click **"Email/Password"**
- Toggle **"Enable"** switch
- (Optional) Toggle **"Email link (passwordless sign-in)"** if you want
- Click **"Save"**

#### Apple:
- Click **"Apple"**
- Toggle **"Enable"** switch
- Click **"Save"**
- **Note**: For iOS-only apps, you don't need to fill in Services ID, Team ID, etc. Those are only required for web-based Apple Sign-In.

---

## 📱 Xcode Project Setup

### Step 1: Add GoogleService-Info.plist to Your Project

1. **Open Xcode** and your project
2. **Drag the `GoogleService-Info.plist` file** from Finder into your Xcode project navigator
3. **Check these settings** in the dialog:
   - ☑️ **"Copy items if needed"** - Must be checked
   - ☑️ **Your app target** - Must be selected
   - Click **"Finish"**
4. **Verify it worked**:
   - Click on `GoogleService-Info.plist` in Xcode
   - In the File Inspector (right sidebar), verify "Target Membership" shows your app with a checkmark

**Important**: The file MUST be named exactly `GoogleService-Info.plist` (no spaces, no extra words).

### Step 2: Add Firebase SDK via Swift Package Manager

1. In Xcode, go to **File → Add Package Dependencies...**
2. In the search field, paste:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
3. Click **"Add Package"**
4. Wait for Xcode to fetch the package
5. **Select these products** (check the boxes):
   - ☑️ **FirebaseAuth**
   - ☑️ **FirebaseCore**
6. Click **"Add Package"**

### Step 3: Configure Firebase in Your App

In your main app file (e.g., `YourAppNameApp.swift`), add Firebase initialization:

```swift
import SwiftUI
import FirebaseCore

// Create an AppDelegate to configure Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct YourAppNameApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var authManager: AuthenticationManager?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let authManager = authManager {
                    if authManager.isAuthenticated {
                        // Show your main app view when authenticated
                        ContentView()
                            .environment(authManager)
                    } else {
                        // Show login when not authenticated
                        LoginView()
                            .environment(authManager)
                    }
                } else {
                    // Show loading while initializing
                    ProgressView()
                }
            }
            .onAppear {
                // Initialize AuthenticationManager after Firebase is configured
                if authManager == nil {
                    authManager = AuthenticationManager()
                }
            }
        }
    }
}
```

**Key points:**
- `FirebaseApp.configure()` MUST be called before any Firebase usage
- `AuthenticationManager` is initialized after Firebase is ready (in `onAppear`)
- The app automatically switches between login and main views based on auth state

### Step 4: Add Sign in with Apple Capability

**Required only if you want Apple Sign-In support.**

1. In Xcode, select your **project** in the navigator
2. Select your **app target**
3. Go to the **"Signing & Capabilities"** tab
4. Make sure you're signed into Xcode:
   - Xcode → Settings → Accounts
   - Add your Apple ID if not present
5. Make sure your **Team** is selected (NOT "Personal Team" - you need a paid Apple Developer account)
6. Click **"+ Capability"**
7. Search for **"Sign in with Apple"**
8. Click to add it
9. You should now see "Sign in with Apple" in your capabilities list

**Troubleshooting**: If you can't add the capability:
- Make sure you're enrolled in the Apple Developer Program ($99/year)
- Your Apple ID must be signed in (Xcode → Settings → Accounts)
- Download/refresh provisioning profiles
- Restart Xcode

---

## 💻 Implementation Files

Now let's create the files needed for authentication. You can copy these directly into your project.

### 1. AuthenticationManager.swift

This is the core authentication manager that handles all Firebase auth operations.

**Copy the existing `AuthenticationManager.swift` from this project** or recreate it with:
- Email/password sign in and sign up
- Apple Sign-In support
- Password reset
- Sign out
- Delete account
- Session management with `@Observable`

See the `AuthenticationManager.swift` file in this project for the complete implementation.

### 2. LoginView.swift

The login screen with email/password fields and Apple Sign-In button.

**Copy the existing `LoginView.swift` from this project** with:
- Email and password text fields
- Sign in button with loading state
- Sign in with Apple button
- Links to sign up and password reset
- Error handling

See the `LoginView.swift` file in this project for the complete implementation.

### 3. SignUpView.swift

Account creation screen for email/password authentication.

**Copy the existing `SignUpView.swift` from this project** with:
- Email and password fields
- Confirm password validation
- Error handling
- Auto-dismiss on successful signup

See the `SignUpView.swift` file in this project for the complete implementation.

### 4. PasswordResetView.swift

Password reset functionality via email.

Create this file or copy from this project - it should include:
- Email input field
- Send reset email button
- Success/error messaging

### 5. SettingsSheet.swift

User settings with sign out and account deletion.

**Important**: Make sure to import FirebaseAuth!

```swift
import SwiftUI
import FirebaseAuth  // ⚠️ Don't forget this import!

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    
    // ... rest of implementation
}
```

See the `SettingsSheet.swift` file in this project for the complete implementation.

---

## 🍎 Apple Sign-In Setup

Apple Sign-In requires additional configuration beyond just adding the capability.

### In Apple Developer Portal

**Only needed if Apple Sign-In fails or for web-based auth. iOS-only apps usually work without this.**

1. Go to [developer.apple.com](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers**
4. Find or create your App ID
5. Make sure **"Sign in with Apple"** capability is enabled
6. Click **Save**

### In Firebase Console (Already Done)

1. Go to Authentication → Sign-in method
2. Enable "Apple" provider
3. Click Save

**Note**: The Services ID, Team ID, Key ID, and Private Key fields are only required for web-based Apple Sign-In. For iOS-only apps, you can leave these blank.

### In Your Code

Make sure your `LoginView` includes the Apple Sign-In button:

```swift
import AuthenticationServices  // Required import

// In your LoginView body:
SignInWithAppleButton(.signIn) { request in
    request.requestedScopes = [.email, .fullName]
    request.nonce = authManager.startSignInWithAppleFlow()
} onCompletion: { result in
    Task {
        await handleAppleSignIn(result)
    }
}
.signInWithAppleButtonStyle(.black)
.frame(height: 50)
.clipShape(RoundedRectangle(cornerRadius: 10))
```

---

## 🧪 Testing & Troubleshooting

### Testing Checklist

Test each feature in this order:

#### 1. App Launches
- [ ] App builds without errors
- [ ] App launches without crashing
- [ ] Login screen appears

#### 2. Email/Password Sign Up
- [ ] Tap "Sign Up" button
- [ ] Enter email and password
- [ ] Successfully creates account
- [ ] Automatically signs in and shows main screen
- [ ] Check Firebase Console → Authentication → Users to see the new user

#### 3. Email/Password Sign In
- [ ] Sign out from settings
- [ ] Return to login screen
- [ ] Enter same credentials
- [ ] Successfully signs in

#### 4. Password Reset
- [ ] Tap "Forgot Password?"
- [ ] Enter email
- [ ] Check email inbox for reset link
- [ ] Click link and reset password
- [ ] Sign in with new password

#### 5. Apple Sign-In
- [ ] Tap "Sign in with Apple" button
- [ ] Apple authentication sheet appears
- [ ] Complete authentication
- [ ] Successfully signs in
- [ ] Check Firebase Console → Authentication → Users to see the Apple user

#### 6. Session Persistence
- [ ] Sign in with any method
- [ ] Force quit the app
- [ ] Reopen the app
- [ ] Should still be signed in

#### 7. Sign Out
- [ ] Open settings
- [ ] Tap "Sign Out"
- [ ] Confirms sign out
- [ ] Returns to login screen

#### 8. Delete Account
- [ ] Sign in
- [ ] Open settings
- [ ] Tap "Delete Account"
- [ ] Confirm deletion
- [ ] Returns to login screen
- [ ] Check Firebase Console - user should be deleted

---

### Common Issues & Solutions

#### ❌ "Could not locate configuration file: 'GoogleService-Info.plist'"

**Problem**: Firebase can't find your configuration file.

**Solutions**:
1. Make sure the file is named **exactly** `GoogleService-Info.plist` (no spaces, no extra words)
2. Check Target Membership:
   - Click on the file in Xcode
   - In File Inspector (right sidebar), check "Target Membership"
   - Your app target must be checked
3. Try removing and re-adding the file:
   - Delete reference in Xcode
   - Drag it back from Finder
   - Make sure "Copy items if needed" is checked

#### ❌ "FirebaseApp.configure() could not find default configuration"

**Problem**: Same as above - the plist file isn't found or is misnamed.

**Solution**: The file might have a space or extra words in the name. Look for files like:
- "Receipt Tracker GoogleService Info.plist" ❌
- "GoogleService-Info (1).plist" ❌
- "GoogleService Info.plist" ❌

Rename to: `GoogleService-Info.plist` ✅

#### ❌ "The default FirebaseApp instance must be configured before..."

**Problem**: You're trying to use Firebase Auth before calling `FirebaseApp.configure()`.

**Solution**: Make sure you're using the AppDelegate pattern shown in this guide:
```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
```

And that `AuthenticationManager` is initialized in `.onAppear`, not directly as a property.

#### ❌ "Property 'uid' is not available due to missing import of defining module 'FirebaseAuth'"

**Problem**: You're using Firebase User properties without importing FirebaseAuth.

**Solution**: Add this import at the top of the file:
```swift
import FirebaseAuth
```

Then clean build: Product → Clean Build Folder (Shift + ⌘ + K)

#### ❌ "The identity provider configuration is not found" (Apple Sign-In)

**Problem**: Apple provider isn't enabled in Firebase Console.

**Solution**:
1. Go to Firebase Console
2. Authentication → Sign-in method
3. Click "Apple"
4. Toggle "Enable" ON
5. Click "Save"

You don't need to fill in Services ID, Team ID, etc. for iOS-only apps.

#### ❌ Apple Sign-In button doesn't appear

**Problem**: Missing import or capability.

**Solution**:
1. Make sure `import AuthenticationServices` is in your LoginView
2. Check Signing & Capabilities tab has "Sign in with Apple"
3. Make sure you're using a paid Apple Developer account (not Personal Team)

#### ❌ "Can't add Sign in with Apple capability"

**Problem**: Not enrolled in Apple Developer Program or using Personal Team.

**Solution**:
1. Enroll in Apple Developer Program ($99/year)
2. Wait 24-48 hours for enrollment to be fully processed
3. In Xcode → Settings → Accounts, remove and re-add your Apple ID
4. In Signing & Capabilities, select your paid team (NOT "Personal Team")
5. Restart Xcode
6. Try adding the capability again

#### ❌ Build errors after adding Firebase

**Problem**: Xcode needs to re-index or derived data is corrupted.

**Solution**:
1. Clean Build Folder: Product → Clean Build Folder (Shift + ⌘ + K)
2. Quit Xcode completely
3. Delete Derived Data:
   - Open Finder
   - Press ⌘ + Shift + G
   - Paste: `~/Library/Developer/Xcode/DerivedData`
   - Delete folders related to your project
4. Reopen Xcode and build

---

## 📱 Optional: Google Sign-In Setup

**Note**: Google Sign-In is not included in the base implementation. Follow these steps if you want to add it.

### Step 1: Add Google Sign-In SDK

1. In Xcode, go to **File → Add Package Dependencies...**
2. Add this package:
   ```
   https://github.com/google/GoogleSignIn-iOS
   ```
3. Select these products:
   - `GoogleSignIn`
   - `GoogleSignInSwift`

### Step 2: Enable Google Provider in Firebase

1. Go to Firebase Console → Authentication → Sign-in method
2. Click **"Google"**
3. Toggle **"Enable"** ON
4. The Web SDK configuration will be auto-populated
5. Click **"Save"**

### Step 3: Configure URL Scheme

1. Open your `GoogleService-Info.plist` file
2. Find the value for `REVERSED_CLIENT_ID` (e.g., `com.googleusercontent.apps.123456789`)
3. Copy this value
4. In Xcode, select your project → target → **Info** tab
5. Expand **"URL Types"**
6. Click **"+"** to add a new URL Type
7. In **"URL Schemes"**, paste the `REVERSED_CLIENT_ID` value
8. Click outside to save

### Step 4: Add Google Sign-In to AuthenticationManager

Add this method to your `AuthenticationManager`:

```swift
import GoogleSignIn

// Add this method to AuthenticationManager
func signInWithGoogle() async throws {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        throw AuthError.invalidGoogleCredentials
    }
    
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config
    
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = windowScene.windows.first?.rootViewController else {
        throw AuthError.invalidGoogleCredentials
    }
    
    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
    
    guard let idToken = result.user.idToken?.tokenString else {
        throw AuthError.invalidGoogleCredentials
    }
    
    let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                    accessToken: result.user.accessToken.tokenString)
    
    let authResult = try await Auth.auth().signIn(with: credential)
    user = authResult.user
}
```

Add this error case to your `AuthError` enum:
```swift
case invalidGoogleCredentials
```

### Step 5: Add Google Sign-In Button to LoginView

Add this import:
```swift
import GoogleSignInSwift
```

Add this button in your LoginView (after Apple Sign-In button):

```swift
Button {
    Task {
        await signInWithGoogle()
    }
} label: {
    HStack {
        Image(systemName: "g.circle.fill")
        Text("Sign in with Google")
            .font(.system(.body, design: .monospaced, weight: .semibold))
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity)
    .frame(height: 50)
    .background(Color(red: 0.26, green: 0.52, blue: 0.96))
    .clipShape(RoundedRectangle(cornerRadius: 10))
}

// Add the handler method
private func signInWithGoogle() async {
    do {
        try await authManager.signInWithGoogle()
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

### Step 6: Test Google Sign-In

1. Build and run
2. Tap "Sign in with Google"
3. Complete Google authentication
4. Should sign in successfully

---

## 🎯 Implementation Summary for New Projects
When copying this authentication system to a new project:

### 1. Firebase Console (5-10 minutes)
- [ ] Create Firebase project
- [ ] Add iOS app with your bundle ID
- [ ] Download `GoogleService-Info.plist`
- [ ] Enable Email/Password authentication
- [ ] Enable Apple authentication

### 2. Xcode Setup (5 minutes)
- [ ] Add `GoogleService-Info.plist` to project (check target membership!)
- [ ] Add Firebase SDK via SPM (`FirebaseAuth`, `FirebaseCore`)
- [ ] Add "Sign in with Apple" capability
- [ ] Verify bundle ID matches Firebase

### 3. Code Files (10-15 minutes)
- [ ] Copy `AuthenticationManager.swift`
- [ ] Copy `LoginView.swift`
- [ ] Copy `SignUpView.swift`
- [ ] Copy `PasswordResetView.swift`
- [ ] Copy `SettingsSheet.swift`
- [ ] Update your App file with Firebase initialization
- [ ] Make sure all files import `FirebaseAuth` where needed

### 4. Testing (5-10 minutes)
- [ ] Run app and verify login screen appears
- [ ] Test email/password sign up
- [ ] Test email/password sign in
- [ ] Test Apple Sign-In
- [ ] Test sign out
- [ ] Test session persistence

**Total time: 25-40 minutes** for a complete authentication system!

---

## 📚 Additional Resources

- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)
- [Firebase iOS Setup Guide](https://firebase.google.com/docs/ios/setup)
- [Apple Sign-In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios)

---

## 🆘 Need Help?

If you encounter issues not covered in this guide:

1. **Check Firebase Console logs**: Authentication → Users tab
2. **Check Xcode console**: Look for Firebase error messages
3. **Verify all imports**: Make sure `import FirebaseAuth` is present
4. **Clean and rebuild**: Product → Clean Build Folder
5. **Restart Xcode**: Sometimes indexing gets stuck

---

**Created for Receipt Tracker project**  
**Last updated**: December 2025  
**Compatible with**: iOS 17+, SwiftUI, Firebase iOS SDK 10+

---

## ✅ Quick Verification Checklist

Before considering the setup complete, verify:

- [ ] `GoogleService-Info.plist` is in project with target membership checked
- [ ] Firebase SDK is added via SPM
- [ ] `FirebaseApp.configure()` is called in AppDelegate
- [ ] Sign in with Apple capability is added (if using Apple Sign-In)
- [ ] All auth files import `FirebaseAuth` where needed
- [ ] Email/Password provider is enabled in Firebase Console
- [ ] Apple provider is enabled in Firebase Console (if using Apple Sign-In)
- [ ] App launches without crashes
- [ ] Can create and sign in with email/password
- [ ] Can sign in with Apple (if enabled)
- [ ] Session persists across app launches
- [ ] Can sign out successfully

**If all items are checked, your Firebase Authentication setup is complete!** ✅

