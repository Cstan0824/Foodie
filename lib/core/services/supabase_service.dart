import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight accessor — use `SupabaseService.client` anywhere in the app.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static String? get currentUserId => currentUser?.id;

  static String requireCurrentUserId() {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('Please sign in to continue.');
    }
    return userId;
  }
}
