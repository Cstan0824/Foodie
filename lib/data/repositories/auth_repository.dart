import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Sign In
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign In with Google (OAuth2)
  Future<bool> signInWithGoogle() async {
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.tastespot://login-callback/',
    );
  }

  // Sign In with Apple (OAuth2)
  Future<bool> signInWithApple() async {
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.tastespot://login-callback/',
    );
  }

  // Sign Up
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    // If signup is successful and we have a user, create their profile
    if (response.user != null) {
      try {
        await _supabase.from('User').insert({
          'user_Id': response.user!.id,
          'name': name,
          'username': name,
        });
      } catch (e) {
        print('Error creating profile: $e');
        // Handle profile creation error (maybe via a trigger in prod instead)
      }
    }

    return response;
  }

  // Forgot Password (Send Reset Email)
  Future<void> resetPassword({required String email}) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get Current User
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }
}
