import 'dart:math';
import 'dart:typed_data';

import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/post_model.dart';

class PostRepository {
  PostRepository._();
  static final PostRepository instance = PostRepository._();

  static const String _postSelect = '''
          post_Id,
          title,
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(
            restaurant_Id,
            restaurant_name,
            mainCuisine:Cuisine!restaurant_main_cuisine_fk(description:desc)
          ),
          Post_Image(image_Id, image_url)
        ''';

  /// Fetches the latest posts for the Discover feed.
  /// Supports offset-based pagination: pass [offset] to load the next page.
  /// Joins: User (author name), Restaurant (name only)
  Future<List<PostModel>> fetchDiscoverPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await SupabaseService.client
        .from('Post')
        .select('''
          post_Id,
          title,
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(restaurant_Id, restaurant_name),
          Post_Image(image_Id, image_url)
        ''')
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches posts from accounts the current user follows.
  Future<List<PostModel>> fetchFollowingPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final followingResponse = await SupabaseService.client
        .from('Follower')
        .select('following_Id')
        .eq('follower_Id', userId);

    final followingIds = (followingResponse as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['following_Id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (followingIds.isEmpty) {
      return const [];
    }

    final response = await SupabaseService.client
        .from('Post')
        .select('''
          post_Id,
          title,
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(restaurant_Id, restaurant_name),
          Post_Image(image_Id, image_url)
        ''')
        .inFilter('user_Id', followingIds)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches public posts by a specific user.
  Future<List<PostModel>> fetchUserPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await SupabaseService.client
        .from('Post')
        .select('''
          post_Id,
          title,
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(restaurant_Id, restaurant_name),
          Post_Image(image_Id, image_url)
        ''')
        .eq('user_Id', userId)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches public posts liked by a specific user.
  Future<List<PostModel>> fetchLikedPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await SupabaseService.client
        .from('Post')
        .select('''
          post_Id,
          title,
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(restaurant_Id, restaurant_name),
          Post_Image(image_Id, image_url),
          Likes!inner(user_Id)
        ''')
        .eq('Likes.user_Id', userId)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single public post by ID.
  Future<PostModel?> fetchPostById(String postId) async {
    final response = await SupabaseService.client
        .from('Post')
        .select('''
          post_Id,
          title,
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(restaurant_Id, restaurant_name),
          Post_Image(image_Id, image_url)
        ''')
        .eq('post_Id', postId)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .maybeSingle();

    if (response == null) return null;
    return PostModel.fromJson(response);
  }

  /// Updates the details, tags, and images of an existing post.
  /// Order mirrors createPost: upload images first, then write to DB.
  ///
  /// Temporary testing choice: image IDs are still generated client-side so the
  /// created UUIDs are known immediately during tests. Long term this should
  /// move to a Supabase-generated/server-managed flow.
  Future<void> updatePost({
    required String postId,
    required String restaurantId,
    required String title,
    required String caption,
    required List<String> deletedImageUrls,
    required List<Uint8List> newImages,
  }) async {
    if (restaurantId.trim().isEmpty) {
      throw Exception('A post must be tied to a restaurant.');
    }

    final postImageRecords = <Map<String, dynamic>>[];
    for (final bytes in newImages) {
      final imageId = _generateUUID();
      final path = 'posts/$postId/$imageId.jpg';

      await SupabaseService.client.storage
          .from('post_images')
          .uploadBinary(path, bytes);

      final publicUrl = SupabaseService.client.storage
          .from('post_images')
          .getPublicUrl(path);

      postImageRecords.add({
        'image_Id': imageId,
        'post_Id': postId,
        'image_url': publicUrl,
      });
    }

    if (deletedImageUrls.isNotEmpty) {
      await SupabaseService.client
          .from('Post_Image')
          .delete()
          .inFilter('image_url', deletedImageUrls);

      // Best-effort: clean up Storage blobs (swallow errors — orphaned blobs are
      // not fatal and can be cleaned up by a maintenance job later).
      final pathsToDelete = deletedImageUrls.map((url) {
        final segments = Uri.parse(url).pathSegments;
        final idx = segments.indexOf('post_images');
        if (idx != -1 && idx + 1 < segments.length) {
          return segments.sublist(idx + 1).join('/');
        }
        return '';
      }).where((p) => p.isNotEmpty).toList();

      if (pathsToDelete.isNotEmpty) {
        try {
          await SupabaseService.client.storage
              .from('post_images')
              .remove(pathsToDelete);
        } catch (_) {}
      }
    }

    // 3. Only now update the Post row — all image work has already succeeded.
    await SupabaseService.client.from('Post').update({
      'title': title,
      'caption': caption,
      'restaurant_Id': restaurantId,
    }).eq('post_Id', postId);

    if (postImageRecords.isNotEmpty) {
      await SupabaseService.client.from('Post_Image').insert(postImageRecords);
    }
  }

  /// User soft delete.
  Future<void> deletePost(String postId) async {
    await SupabaseService.client
        .from('Post')
        .update({'isRemoved': true})
        .eq('post_Id', postId);
  }

  /// Admin block.
  Future<void> blockPost(String postId) async {
    final response = await SupabaseService.client
        .from('Post')
        .update({'isBlocked': true})
        .eq('post_Id', postId)
        .select('post_Id')
        .maybeSingle();

    if (response == null) {
      throw Exception('This post is no longer available.');
    }
  }

  /// Creates a new post with images uploaded to Supabase Storage.
  ///
  /// Temporary testing choice: this method still generates UUIDs client-side so
  /// the created IDs are visible immediately and can be used in storage paths.
  /// Long term this should move to Supabase-generated UUIDs via a server-side flow.
  Future<String> createPost({
    required String userId,
    required String restaurantId,
    required String title,
    required String caption,
    List<Uint8List> images = const [],
  }) async {
    if (restaurantId.trim().isEmpty) {
      throw Exception('A post must be tied to a restaurant.');
    }

    final postId = _generateUUID();
    final postImageRecords = <Map<String, dynamic>>[];

    for (final bytes in images) {
      final imageId = _generateUUID();
      final path = 'posts/$postId/$imageId.jpg';

      await SupabaseService.client.storage
          .from('post_images')
          .uploadBinary(path, bytes);

      final publicUrl = SupabaseService.client.storage
          .from('post_images')
          .getPublicUrl(path);

      postImageRecords.add({
        'image_Id': imageId,
        'post_Id': postId,
        'image_url': publicUrl,
      });
    }

    await SupabaseService.client.from('Post').insert({
      'post_Id': postId,
      'user_Id': userId,
      'restaurant_Id': restaurantId,
      'title': title,
      'caption': caption,
      'isRemoved': false,
      'isBlocked': false,
      'isPending': false,
      'likeCount': 0,
      'saveCount': 0,
    });

    if (postImageRecords.isNotEmpty) {
      await SupabaseService.client.from('Post_Image').insert(postImageRecords);
    }

    return postId;
  }

  // We still generate these client-side for testing and storage-path construction.
  static final _secureRand = Random.secure();

  String _generateUUID() {
    final bytes = List<int>.generate(16, (_) => _secureRand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
        '-${hex.substring(20)}';
  }
  /// Toggles the like status of a post. The post likeCount is handled automatically via a backend Postgres Trigger.
  Future<void> toggleLike(String postId, String userId, bool isLiking) async {
    if (isLiking) {
      await SupabaseService.client.from('Likes').insert({
        'post_Id': postId,
        'user_Id': userId,
      });
      return;
    }

    await SupabaseService.client
        .from('Likes')
        .delete()
        .eq('post_Id', postId)
        .eq('user_Id', userId);
  }

  Future<bool> checkIsLiked(String postId, String userId) async {
    final response = await SupabaseService.client
        .from('Likes')
        .select('post_Id')
        .eq('post_Id', postId)
        .eq('user_Id', userId)
        .maybeSingle();
    return response != null;
  }

  Future<void> reportPost({
    required String postId,
    required String userId,
    required String reason,
    String? details,
  }) async {
    await _ensurePostAvailable(postId);

    try {
      await SupabaseService.client.from('Report').insert({
        'post_Id': postId,
        'user_Id': userId,
        'reason': reason,
        'details': details,
        'status': 0,
      });
    } catch (e) {
      final message = e.toString();
      if (message.contains('23505') || message.contains('duplicate key')) {
        throw Exception('You have already reported this post.');
      }
      if (message.contains('Users cannot report their own posts')) {
        throw Exception('You cannot report your own post.');
      }
      rethrow;
    }
  }

  Future<void> _ensurePostAvailable(String postId) async {
    final response = await SupabaseService.client
        .from('Post')
        .select('post_Id')
        .eq('post_Id', postId)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .maybeSingle();

    if (response == null) {
      throw Exception('This post is no longer available.');
    }
  }
}
