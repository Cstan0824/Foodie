import 'dart:math';
import 'dart:typed_data';

import 'package:taste_spot/core/utils/hashtag_utils.dart';
import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/repositories/repository_support.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/data/repositories/notification_repository.dart';

class PostRepository {
  PostRepository._();
  static final PostRepository instance = PostRepository._();

  final _notifRepo = NotificationRepository(SupabaseService.client);

  /// Fetches the latest posts for the Discover feed.
  /// Supports offset-based pagination: pass [offset] to load the next page.
  /// Joins: User (author name), Restaurant (name only)
  Future<List<PostModel>> fetchDiscoverPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('Post')
          .select(publicPostSelect)
          .eq('isRemoved', false)
          .eq('isBlocked', false)
          .eq('isPending', false)
          .order('created_At', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      print(
        '❌ [PostRepository.fetchDiscoverPosts] ERROR: ${e.code} - ${e.message}',
      );
      print('📝 Hint: ${e.hint}');
      print('📊 Details: ${e.details}');
      rethrow;
    } catch (e) {
      print('❌ [PostRepository.fetchDiscoverPosts] UNKNOWN ERROR: $e');
      rethrow;
    }
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
        .select(publicPostSelect)
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
        .select(publicPostSelect)
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

  /// Fetches posts the user has archived (soft-deleted) — isRemoved = true.
  Future<List<PostModel>> fetchArchivedPosts({required String userId}) async {
    final response = await SupabaseService.client
        .from('Post')
        .select(publicPostSelect)
        .eq('user_Id', userId)
        .eq('isRemoved', true)
        .eq('visible_to_owner', true)
        .order('created_At', ascending: false);

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
          $publicPostSelect,
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

  /// Fetches a single post by ID.
  ///
  /// By default this only returns visible public posts. Set [includeRemoved]
  /// for owner-only archive flows that need to read a soft-deleted post.
  Future<PostModel?> fetchPostById(
    String postId, {
    bool includeRemoved = false,
  }) async {
    final baseQuery = SupabaseService.client
        .from('Post')
        .select(publicPostSelect)
        .eq('post_Id', postId)
        .eq('isBlocked', false)
        .eq('isPending', false);

    final response =
        await (includeRemoved ? baseQuery : baseQuery.eq('isRemoved', false))
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
    List<String> hashtags = const [],
    required List<String> deletedImageUrls,
    required List<Uint8List> newImages,
  }) async {
    if (restaurantId.trim().isEmpty) {
      throw Exception('A post must be tied to a restaurant.');
    }
    final normalizedHashtags = _normalizeAndValidateHashtags(hashtags);

    await _ensurePostEditable(postId);

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
      final pathsToDelete = deletedImageUrls
          .map((url) {
            final segments = Uri.parse(url).pathSegments;
            final idx = segments.indexOf('post_images');
            if (idx != -1 && idx + 1 < segments.length) {
              return segments.sublist(idx + 1).join('/');
            }
            return '';
          })
          .where((p) => p.isNotEmpty)
          .toList();

      if (pathsToDelete.isNotEmpty) {
        try {
          await SupabaseService.client.storage
              .from('post_images')
              .remove(pathsToDelete);
        } catch (_) {}
      }
    }

    // 3. Only now update the Post row — all image work has already succeeded.
    await SupabaseService.client
        .from('Post')
        .update({
          'title': title,
          'caption': caption,
          'restaurant_Id': restaurantId,
        })
        .eq('post_Id', postId);

    if (postImageRecords.isNotEmpty) {
      await SupabaseService.client.from('Post_Image').insert(postImageRecords);
    }

    await _syncPostHashtags(postId, normalizedHashtags);
  }

  /// User soft delete.
  Future<void> deletePost(String postId) async {
    final currentUserId = SupabaseService.requireCurrentUserId();

    final response = await SupabaseService.client
        .from('Post')
        .update({'isRemoved': true, 'visible_to_owner': true})
        .eq('post_Id', postId)
        .eq('user_Id', currentUserId)
        .select('post_Id')
        .maybeSingle();

    if (response == null) {
      throw Exception('This post is no longer available.');
    }
  }

  /// Restore a soft-deleted post back to the normal profile/feed state.
  Future<void> restorePost(String postId) async {
    final currentUserId = SupabaseService.requireCurrentUserId();

    final response = await SupabaseService.client
        .from('Post')
        .update({'isRemoved': false, 'visible_to_owner': true})
        .eq('post_Id', postId)
        .eq('user_Id', currentUserId)
        .select('post_Id')
        .maybeSingle();

    if (response == null) {
      throw Exception('This post could not be recovered.');
    }
  }

  /// Hide a previously deleted post from the owner's archive while keeping it
  /// available for admin/audit access.
  Future<void> hideDeletedPostFromOwner(String postId) async {
    final currentUserId = SupabaseService.requireCurrentUserId();

    final response = await SupabaseService.client
        .from('Post')
        .update({'visible_to_owner': false})
        .eq('post_Id', postId)
        .eq('user_Id', currentUserId)
        .eq('isRemoved', true)
        .select('post_Id')
        .maybeSingle();

    if (response == null) {
      throw Exception('This post could not be removed from your archive.');
    }
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
    String? restaurantId,
    String? restaurantApprovalId,
    required String title,
    required String caption,
    List<String> hashtags = const [],
    List<Uint8List> images = const [],
  }) async {
    final hasRestaurant =
        restaurantId != null && restaurantId.trim().isNotEmpty;
    final hasApproval =
        restaurantApprovalId != null && restaurantApprovalId.trim().isNotEmpty;

    if (!hasRestaurant && !hasApproval) {
      throw Exception(
        'A post must be tied to a restaurant or pending restaurant approval.',
      );
    }
    if (hasRestaurant && hasApproval) {
      throw Exception(
        'Post cannot use both an approved restaurant and pending restaurant approval.',
      );
    }

    final normalizedHashtags = _normalizeAndValidateHashtags(hashtags);

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
      'restaurant_Id': hasRestaurant ? restaurantId : null,
      'restaurant_approval_id': hasApproval ? restaurantApprovalId : null,
      'title': title,
      'caption': caption,
      'isRemoved': false,
      'visible_to_owner': true,
      'isBlocked': false,
      'isPending': hasApproval,
      'likeCount': 0,
      'saveCount': 0,
    });

    if (postImageRecords.isNotEmpty) {
      await SupabaseService.client.from('Post_Image').insert(postImageRecords);
    }

    await _syncPostHashtags(postId, normalizedHashtags);

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

  Future<List<String>> searchHashtags(String query, {int limit = 6}) async {
    final normalizedQuery = HashtagUtils.normalizeToken(query);
    if (normalizedQuery.isEmpty ||
        HashtagUtils.validateToken(normalizedQuery) != null) {
      return const [];
    }

    final response = await SupabaseService.client
        .from('hashtag')
        .select('name')
        // Use a contains match so legacy rows like "#sushi" still show up
        // while the app transitions to normalized storage without "#".
        .ilike('name', '%$normalizedQuery%')
        .order('name', ascending: true)
        .range(0, limit - 1);

    final normalizedResults = HashtagUtils.normalizeAll(
      (response as List<dynamic>).map(
        (row) => (row as Map<String, dynamic>)['name']?.toString() ?? '',
      ),
    ).where((tag) => tag.contains(normalizedQuery)).toList();

    normalizedResults.sort((a, b) {
      final aExact = a == normalizedQuery;
      final bExact = b == normalizedQuery;
      if (aExact != bExact) return aExact ? -1 : 1;

      final aPrefix = a.startsWith(normalizedQuery);
      final bPrefix = b.startsWith(normalizedQuery);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;

      final lengthCompare = a.length.compareTo(b.length);
      if (lengthCompare != 0) return lengthCompare;
      return a.compareTo(b);
    });

    return normalizedResults.take(limit).toList();
  }

  List<String> _normalizeAndValidateHashtags(List<String> hashtags) {
    final normalized = HashtagUtils.normalizeAll(hashtags);
    final error = HashtagUtils.validateList(normalized);
    if (error != null) {
      throw Exception(error);
    }
    return normalized;
  }

  Future<void> _syncPostHashtags(String postId, List<String> hashtags) async {
    await SupabaseService.client
        .from('post_hashtag')
        .delete()
        .eq('post_Id', postId);

    if (hashtags.isEmpty) {
      return;
    }

    await SupabaseService.client
        .from('hashtag')
        .upsert(
          hashtags.map((tag) => {'name': tag}).toList(),
          onConflict: 'name',
        );

    final hashtagRows = await SupabaseService.client
        .from('hashtag')
        .select('hashtag_id, name')
        .inFilter('name', hashtags);

    final hashtagIdsByName = <String, String>{};
    for (final row in hashtagRows as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      final name = map['name']?.toString();
      final id = map['hashtag_id']?.toString();
      if (name != null && id != null && name.isNotEmpty && id.isNotEmpty) {
        hashtagIdsByName[name] = id;
      }
    }

    final missingTags = hashtags.where(
      (tag) => !hashtagIdsByName.containsKey(tag),
    );
    if (missingTags.isNotEmpty) {
      throw Exception('Failed to save hashtags.');
    }

    await SupabaseService.client
        .from('post_hashtag')
        .insert(
          hashtags
              .map(
                (tag) => {
                  'post_Id': postId,
                  'hashtag_id': hashtagIdsByName[tag],
                },
              )
              .toList(),
        );
  }

  /// Toggles the like status of a post. The post likeCount is handled automatically via a backend Postgres Trigger.
  Future<void> toggleLike(String postId, String userId, bool isLiking) async {
    await ensurePostAvailable(
      postId,
      errorMessage: 'This post is no longer available.',
    );

    if (isLiking) {
      await SupabaseService.client.from('Likes').insert({
        'post_Id': postId,
        'user_Id': userId,
      });

      // Trigger notification
      _triggerLikeNotification(postId, userId);
      return;
    }

    await SupabaseService.client
        .from('Likes')
        .delete()
        .eq('post_Id', postId)
        .eq('user_Id', userId);
  }

  Future<void> _triggerLikeNotification(String postId, String userId) async {
    try {
      final postData = await SupabaseService.client
          .from('Post')
          .select('user_Id')
          .eq('post_Id', postId)
          .maybeSingle();

      final postOwnerId = postData?['user_Id'] as String?;
      if (postOwnerId != null) {
        await _notifRepo.notifyLike(
          likerId: userId,
          postOwnerId: postOwnerId,
          postId: postId,
        );
      }
    } catch (_) {}
  }

  Future<bool> checkIsLiked(String postId, String userId) async {
    await ensurePostAvailable(
      postId,
      errorMessage: 'This post is no longer available.',
    );

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
    await ensurePostAvailable(
      postId,
      errorMessage: 'This post is no longer available.',
    );

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

  Future<void> _ensurePostEditable(String postId) async {
    final response = await SupabaseService.client
        .from('Post')
        .select('post_Id')
        .eq('post_Id', postId)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .maybeSingle();

    if (response == null) {
      throw Exception('This post is no longer available.');
    }
  }
}
