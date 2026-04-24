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
    final response = await _supabase
        .from('User')
        .select('user_Id')
        .ilike('email', normalized)
        .limit(1);
    return (response as List<dynamic>).isNotEmpty;
  }

  // Sign Up
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final usernameAvailable = await isUsernameAvailable(name);
    if (!usernameAvailable) {
      throw Exception('USERNAME_TAKEN');
    }

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
          'email': email.trim().toLowerCase(),
        });

        // Create default collections
        await _supabase.from('collections').insert([
          {
            'collection_Id': const Uuid().v4(),
            'user_Id': response.user!.id,
            'name': 'Saved Posts',
            'is_public': false,
            'collection_type': 'POST',
          },
          {
            'collection_Id': const Uuid().v4(),
            'user_Id': response.user!.id,
            'name': 'Restaurant',
            'is_public': false,
            'collection_type': 'POST',
          }
        ]);
      } on PostgrestException catch (e) {
        if (e.code == '23505' &&
            (e.message.contains('User_username_key') ||
                (e.details?.toString().contains('(username)=') ?? false))) {
          throw Exception('USERNAME_TAKEN');
        }
        throw Exception('PROFILE_CREATE_FAILED');
      } catch (_) {
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
}
