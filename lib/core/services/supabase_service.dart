import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight accessor — use `SupabaseService.client` anywhere in the app.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
}
