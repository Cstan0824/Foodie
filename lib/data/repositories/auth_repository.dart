import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Sign In
  Future<AuthResponse> signIn({
    required String identifier,
    required String password,
  }) async {
    final isEmail = identifier.contains('@');
    if (isEmail) {
      return await _supabase.auth.signInWithPassword(
        email: identifier,
        password: password,
      );
    } else {
      return await _supabase.auth.signInWithPassword(
        phone: identifier,
        password: password,
      );
    }
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

  Future<bool> isUsernameAvailable(
    String username, {
    String? excludingUserId,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    var query = _supabase
        .from('User')
        .select('user_Id')
        .ilike('username', normalized);

    if (excludingUserId != null && excludingUserId.isNotEmpty) {
      query = query.neq('user_Id', excludingUserId);
    }

    final response = await query.limit(1);
    return (response as List<dynamic>).isEmpty;
  }

  Future<bool> isEmailRegistered(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    
    try {
      // Use the RPC function we created in Supabase
      final bool exists = await _supabase.rpc('check_email_exists', params: {'email_to_check': normalized});
      return exists;
    } catch (e) {
      // If RPC fails (e.g. not created yet), return false immediately to prevent UI hang.
      // Do NOT fallback to User table as it lacks the email column.
      print('Email check skipped: Ensure "check_email_exists" RPC is created in Supabase. Error: $e');
      return false; 
    }
  }

  // Sign Up
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    String? emailRedirectTo,
  }) async {
    // 1. Double check username availability
    final usernameAvailable = await isUsernameAvailable(name);
    if (!usernameAvailable) {
      throw Exception('USERNAME_TAKEN');
    }

    // 2. Auth signup
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectTo ?? 'io.supabase.tastespot://login-callback/',
    );

    // 3. Create profile if auth was successful
    if (response.user != null) {
      try {
        await _supabase.from('User').insert({
          'user_Id': response.user!.id,
          'name': name,
          'username': name.toLowerCase().trim(),
          // We removed 'email' here because it belongs to auth.users, not public.User
          'password': 'SUPABASE_AUTH_USER', 
        });

        // Create default collections
        await _supabase.from('collections').insert([
          {
            'collection_Id': const Uuid().v4(),
            'user_Id': response.user!.id,
            'name': 'Saved Posts',
            'is_public': false,
            'collection_type': 'POST',
            'is_default': true,
          },
          {
            'collection_Id': const Uuid().v4(),
            'user_Id': response.user!.id,
            'name': 'Saved Restaurants',
            'is_public': false,
            'collection_type': 'RESTAURANT',
            'is_default': true,
          }
        ]);
      } on PostgrestException catch (e) {
        print('Profile creation error: ${e.message}');
        if (e.code == '23505') throw Exception('USERNAME_TAKEN');
        throw Exception('PROFILE_CREATE_FAILED');
      } catch (e) {
        throw Exception('PROFILE_CREATE_FAILED');
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

  // Verify Email OTP (for Sign Up)
  Future<AuthResponse> verifySignUpOtp({
    required String email,
    required String token,
  }) async {
    return await _supabase.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: token,
    );
  }

  // Verify Recovery OTP (for Password Reset)
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    return await _supabase.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: token,
    );
  }

  // Update Password
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // Delete Account
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // 1. Delete the public profile first
    await _supabase.from('User').delete().eq('user_Id', user.id);

    // 2. Sign out (The actual auth user deletion usually requires an Edge Function or Admin API)
    // For this prototype, we'll delete the profile and sign out.
    await _supabase.auth.signOut();
  }
}
