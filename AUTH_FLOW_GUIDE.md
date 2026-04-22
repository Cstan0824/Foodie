# Taste Spot 🔐 Authentication Flow Guide

This document explains how the entire authentication flow works in the **Taste Spot** app, from the UI down to the Supabase backend, including native deep-links for OAuth (Google/Apple).

---

## 1. The Data Layer (`AuthRepository`)
The `AuthRepository` acts as the middleman between the app and Supabase. It abstracts away the direct database calls so our UI code stays remarkably clean.

**File:** `lib/data/repositories/auth_repository.dart`

### Email & Password Sign Up
When a user creates an account, we use `auth.signUp`. Crucially, right after successful authentication, we immediately create their public profile using the `user.id`.

```dart
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    // If signup is successful, insert into the public.profiles table
    if (response.user != null) {
      try {
        await _supabase.from('profiles').insert({
          'user_id': response.user!.id,
          'name': name,
        });
      } catch (e) {
        print('Error creating profile: $e');
      }
    }
    return response;
  }
```

### OAuth (Google & Apple)
Supabase handles all the OAuth security for us. We pass `redirectTo` so Supabase knows how to redirect the browser back to our app.

```dart
  // Sign In with Google
  Future<bool> signInWithGoogle() async {
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.tastespot://login-callback/',
    );
  }
```

---

## 2. The Presentation Layer (`LoginScreen` & `SignupScreen`)
The UI is responsible for gathering user inputs, triggering the `AuthRepository`, tracking loading states (`_isLoading`), and catching/displaying errors.

**File:** `lib/features/auth/screens/login_screen.dart`

When a user taps the Google button:

```dart
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. Calls the repository
      await _authRepo.signInWithGoogle();
      // 2. Supabase takes over, opens native browser, handles token exchange.
    } catch (e) {
      if (!mounted) return;
      _showErrorAlert('An error occurred during Google Login.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
```

For email/password login, we catch specific Supabase `AuthException`s to provide nice, readable errors:

```dart
  Future<void> _login() async {
    // ... validation + loading state ...
    try {
      await _authRepo.signIn(email: email, password: password);
      if (!mounted) return;
      
      // Success! Move to MainShell
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const MainShell()),
      );
    } on AuthException catch (e) {
      // Supabase-specific errors (e.g. "Invalid Login Credentials")
      if (!mounted) return;
      _showErrorAlert(e.message);
    } 
    // ...
  }
```

---

## 3. The Native Deep Linking Layer (OS specific)
When Supabase finishes OAuth in the browser, it requests the URL: 
`io.supabase.tastespot://login-callback/`

Both Android and iOS need configuration to recognize this URL scheme so they know to re-open the Taste Spot app.

### Android
**File:** `android/app/src/main/AndroidManifest.xml`
We added a specific Intent Filter listening for our schema:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <!-- Catches io.supabase.tastespot://login-callback -->
    <data android:scheme="io.supabase.tastespot" android:host="login-callback" />
</intent-filter>
```

### iOS
**File:** `ios/Runner/Info.plist`
We registered a URL Type for the iOS ecosystem:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.tastespot</string>
        </array>
    </dict>
</array>
```

---

## 4. The Supabase Dashboard Layer
The code above handles the App/Client side. For it to work fully, the Supabase Dashboard acts as the traffic controller:

1. **Authentication > URL Configuration > Redirect URLs**:
   Must have `io.supabase.tastespot://login-callback/` added. If this is missing, Supabase blocks the request for safety (Error 400).
2. **Authentication > Providers > Google/Apple**:
   Must be enabled and supplied with Google/Apple Client IDs and Client Secrets so Supabase is legally authorized to act on behalf of your Developer accounts.

---

## 5. Session Management & Persistence
Once the user is logged in, the `supabase_flutter` SDK automatically handles token lifecycle and session persistence without manual intervention.

* **Secure Local Storage**: Upon successfully intercepting the deep link and getting the session, the SDK encrypts and saves the `AccessToken` and `RefreshToken` locally on the device (using platform-specific secure storage).
* **App Restarts (Persistent Session)**: When the app is closed and reopened, calling `Supabase.initialize()` automatically checks local storage for existing session tokens, validates them, and restores the user context. The session is accessible immediately via `Supabase.instance.client.auth.currentUser`.
* **Automatic Token Refreshing**: Access tokens typically expire after an hour for security. The Supabase SDK seamlessly intercepts database requests when the token expires, uses the saved `RefreshToken` to retrieve a new `AccessToken` from the server, updates local storage, and then proceeds with the request without disrupting the user experience.

---

### Detailed OAuth2 Flow Summary
1. **User Action:** The user taps "Sign in with Google" or "Sign in with Apple".
2. **Triggering Auth:** The app calls `signInWithOAuth`, providing the provider and redirect URL (`io.supabase.tastespot://login-callback/`).
3. **Browser Opens:** Supabase securely opens a system web browser.
4. **User Authenticates:** The user enters credentials or authorizes via biometric prompts on the provider's website.
5. **Token Exchange:** The provider sends an authorization code to the Supabase project backend, which verifies the code and generates a secure user session.
6. **Deep Link Redirect:** Supabase redirects the browser to the deep link (`io.supabase.tastespot://login-callback/`) passing the session data via URL fragment parameters.
7. **App Interception:** The OS (via Android `<intent-filter>` or iOS `CFBundleURLTypes`) recognizes the `io.supabase.tastespot` scheme, closes the browser, and passes the URL back into the foregrounded app.
8. **Auth State Update:** The `supabase_flutter` SDK automatically parses the tokens from the incoming deep link URL, updates local storage, and triggers the `onAuthStateChange` stream listener to navigate the user seamlessly into the app.