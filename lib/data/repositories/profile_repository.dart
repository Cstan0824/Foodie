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

  Future<String?> uploadProfileImage(
    String userId,
    Uint8List imageBytes,
  ) async {
    // Keep one image row per user by reusing userId as image_id.
    try {
      await _supabase.from('UserImage').upsert({
        'image_id': userId,
        'user_Id': userId,
        'profile_image': imageBytes,
      }, onConflict: 'image_id');
      return "Success";
    } catch (e) {
      print('Image Upload Error: $e');
      return null;
    }
  }

  Future<Uint8List?> getProfileImage(String userId) async {
    final response = await _supabase
        .from('UserImage')
        .select('profile_image')
        .eq('user_Id', userId)
        .maybeSingle();

    if (response == null || response['profile_image'] == null) return null;
    // Assuming binary data returned as List<int>
    return Uint8List.fromList(List<int>.from(response['profile_image']));
  }

  Future<int> getFollowersCount(String userId) async {
    final response = await _supabase
        .from('Follower')
        .select('follower_Id')
        .eq('following_Id', userId);
    return (response as List).length;
  }

  Future<int> getFollowingCount(String userId) async {
    final response = await _supabase
        .from('Follower')
        .select('following_Id')
        .eq('follower_Id', userId);
    return (response as List).length;
  }

  Future<List<Profile>> getFollowers(String userId) async {
    final response = await _supabase
        .from('Follower')
        .select('follower_Id, User!Follower_follower_Id_fkey(user_Id, name, username, bio, created_At)')
        .eq('following_Id', userId);

    return (response as List).map((row) {
      final userJson = row['User'] as Map<String, dynamic>;
      return Profile.fromJson(userJson);
    }).toList();
  }

  Future<List<Profile>> getFollowing(String userId) async {
    final response = await _supabase
        .from('Follower')
        .select('following_Id, User!Follower_following_Id_fkey(user_Id, name, username, bio, created_At)')
        .eq('follower_Id', userId);

    return (response as List).map((row) {
      final userJson = row['User'] as Map<String, dynamic>;
      return Profile.fromJson(userJson);
    }).toList();
  }
}
