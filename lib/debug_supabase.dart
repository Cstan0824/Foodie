import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;

class SupabaseDebugger {
  static Future<void> runFullDiagnostic() async {
    dev.log('🚀 Starting Supabase Diagnostics...', name: 'DEBUG');
    
    final client = Supabase.instance.client;
    
    // 1. Check Auth State
    final user = client.auth.currentUser;
    dev.log('👤 Current User: ${user?.id ?? "Not logged in"}', name: 'DEBUG');
    dev.log('🔑 Session Valid: ${client.auth.currentSession != null}', name: 'DEBUG');

    // 2. Test Simple Query (No Joins)
    dev.log('📡 Testing simple table query (User)...', name: 'DEBUG');
    try {
      final res = await client.from('User').select('user_Id').limit(1);
      dev.log('✅ Simple Query Success: $res', name: 'DEBUG');
    } catch (e) {
      _logError('Simple Query (User)', e);
    }

    // 3. Test Complex Join (Post + User)
    dev.log('🔗 Testing Post + User join...', name: 'DEBUG');
    try {
      final res = await client.from('Post').select('post_Id, User:user_Id(name)').limit(1);
      dev.log('✅ Join Query Success: $res', name: 'DEBUG');
    } catch (e) {
      _logError('Join Query (Post+User)', e);
    }

    // 4. Test Notification Table
    dev.log('🔔 Testing Notification table...', name: 'DEBUG');
    try {
      final res = await client.from('Notification').select('id').limit(1);
      dev.log('✅ Notification Table Success', name: 'DEBUG');
    } catch (e) {
      _logError('Notification Table', e);
    }
  }

  static void _logError(String context, dynamic e) {
    if (e is PostgrestException) {
      dev.log('❌ $context ERROR: [${e.code}] ${e.message}', name: 'DEBUG');
      dev.log('📝 Hint: ${e.hint}', name: 'DEBUG');
      dev.log('📊 Details: ${e.details}', name: 'DEBUG');
    } else {
      dev.log('❌ $context UNKNOWN ERROR: $e', name: 'DEBUG');
    }
  }
}
