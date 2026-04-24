import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'dart:typed_data';

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  Future<Profile?> getProfile(String userId) async {
    final response = await _supabase
        .from('User')
        .select('user_Id, name, username, bio, role, created_At, UserImage(image_url)')
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
    try {
      final fileName = 'avatar_$userId.png';
      final path = 'avatars/$fileName';

      // 1. Upload to Supabase Storage bucket 'user_images'
      await _supabase.storage.from('user_images').uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
          );

      // 2. Get the public URL
      final imageUrl = _supabase.storage.from('user_images').getPublicUrl(path);

      // 3. Update the UserImage table with the new URL
      await _supabase.from('UserImage').upsert({
        'image_id': userId,
        'user_Id': userId,
        'image_url': imageUrl,
      }, onConflict: 'image_id');

      return imageUrl;
    } catch (e) {
      print('Image Upload Error: $e');
      return null;
    }
  }

  Future<String?> getProfileImageUrl(String userId) async {
    try {
      final response = await _supabase
          .from('UserImage')
          .select('image_url')
          .eq('user_Id', userId)
          .maybeSingle();

      if (response == null || response['image_url'] == null) return null;
      return response['image_url'] as String;
    } catch (e) {
      // If UserImage fails, try avatar_url on User table (fallback)
      try {
        final fallback = await _supabase
            .from('User')
            .select('avatar_url')
            .eq('user_Id', userId)
            .maybeSingle();
        return fallback?['avatar_url'] as String?;
      } catch (_) {
        return null;
      }
    }
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
        .select('follower_Id, User!Follower_follower_Id_fkey(user_Id, name, username, bio, role, created_At, UserImage(image_url))')
        .eq('following_Id', userId);

    return (response as List).map((row) {
      final userJson = row['User'] as Map<String, dynamic>;
      return Profile.fromJson(userJson);
    }).toList();
  }

  Future<List<Profile>> getFollowing(String userId) async {
    final response = await _supabase
        .from('Follower')
        .select('following_Id, User!Follower_following_Id_fkey(user_Id, name, username, bio, role, created_At, UserImage(image_url))')
        .eq('follower_Id', userId);

    return (response as List).map((row) {
      final userJson = row['User'] as Map<String, dynamic>;
      return Profile.fromJson(userJson);
    }).toList();
  }

  Future<bool> checkIsFollowing({
    required String followerId,
    required String followingId,
  }) async {
    final response = await _supabase
        .from('Follower')
        .select('follower_Id')
        .eq('follower_Id', followerId)
        .eq('following_Id', followingId)
        .maybeSingle();

    return response != null;
  }

  Future<void> setFollowing({
    required String followerId,
    required String followingId,
    required bool isFollowing,
  }) async {
    if (isFollowing) {
      await _supabase.from('Follower').upsert({
        'follower_Id': followerId,
        'following_Id': followingId,
      }, onConflict: 'follower_Id,following_Id');
      return;
    }

    await _supabase
        .from('Follower')
        .delete()
        .eq('follower_Id', followerId)
        .eq('following_Id', followingId);
  }
}
