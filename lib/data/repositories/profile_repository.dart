import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'dart:typed_data';

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  Future<Profile?> getProfile(String userId) async {
    final response = await _supabase
        .from('User')
        .select()
        .eq('user_Id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  Future<void> updateProfile({
    required String userId,
    required String name,
    String? bio,
  }) async {
    await _supabase.from('User').upsert({
      'user_Id': userId,
      'name': name,
      if (bio != null) 'bio': bio,
    });
  }

  Future<String?> uploadProfileImage(String userId, Uint8List imageBytes) async {
    // 1. Upload to storage bucket (ensure you run this setup locally or fallback to bytes)
    // 2. Or insert directly into public.user_image if that's preferred in your exact schema.
    try {
      await _supabase.from('user_image').insert({
        'user_id': userId,
        'profile_image': imageBytes, // In Supabase Dart, sending bytea could require hex/base64 encoding or just relying on standard supabase behavior
      });
      return "Success";
    } catch (e) {
      print('Image Upload Error: $e');
      return null;
    }
  }

  Future<Uint8List?> getProfileImage(String userId) async {
    final response = await _supabase
        .from('user_image')
        .select('profile_image')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null || response['profile_image'] == null) return null;
    // Assuming binary data returned as List<int>
    return Uint8List.fromList(List<int>.from(response['profile_image']));
  }
}
