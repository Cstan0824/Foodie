import 'dart:math';
import 'dart:typed_data';

import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/post_model.dart';

class PostRepository {
  PostRepository._();
  static final PostRepository instance = PostRepository._();

  /// Fetches the latest posts for the Discover feed.
  /// Supports offset-based pagination: pass [offset] to load the next page.
  /// Joins: User (author name), Restaurant (name + cuisine)
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
          Restaurant(restaurant_Id, restaurant_name, categoryCuisine),
          Post_Image(image_Id, image_url)
        ''')
        .eq('isRemoved', false)
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches posts by a specific user.
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
          Restaurant(restaurant_Id, restaurant_name, categoryCuisine),
          Post_Image(image_Id, image_url)
        ''')
        .eq('user_Id', userId)
        .eq('isRemoved', false)
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches posts liked by a specific user.
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
          Restaurant(restaurant_Id, restaurant_name, categoryCuisine),
          Post_Image(image_Id, image_url),
          Likes!inner(user_Id)
        ''')
        .eq('Likes.user_Id', userId)
        .eq('isRemoved', false)
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single post by ID, including author + restaurant info.
  Future<PostModel?> fetchPostById(String postId) async {
    final response = await SupabaseService.client
        .from('Post')
        .select('''
          post_Id,
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(restaurant_Id, restaurant_name, categoryCuisine),
          Post_Image(image_Id, image_url)
        ''')
        .eq('post_Id', postId)
        .maybeSingle();

    if (response == null) return null;
    return PostModel.fromJson(response as Map<String, dynamic>);
  }

  /// Updates the details, tags, and images of an existing post.
  /// Order mirrors createPost: upload images FIRST (fail fast), then write to DB.
  Future<void> updatePost({
    required String postId,
    String? restaurantId,
    required String title,
    required String caption,
    required List<String> deletedImageUrls,
    required List<Uint8List> newImages,
  }) async {
    // 1. Upload ALL new images first — fail fast before touching the DB.
    //    (Same pattern as createPost: if any upload throws, nothing in the DB changes.)
    final List<Map<String, dynamic>> postImageRecords = [];
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

    // 2. Remove deleted images from DB and Storage.
    //    Done before the Post update so any deletion failure surfaces early.
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

    // 4. Insert new Post_Image records linking the freshly-uploaded images.
    if (postImageRecords.isNotEmpty) {
      await SupabaseService.client.from('Post_Image').insert(postImageRecords);
    }
  }

  /// Soft deletes a post by setting isRemoved = true
  Future<void> deletePost(String postId) async {
    await SupabaseService.client
        .from('Post')
        .update({'isRemoved': true})
        .eq('post_Id', postId);
  }

  /// Fetches all posts by a specific user.
  Future<List<PostModel>> fetchPostsByUser(String userId,
      {int limit = 50}) async {
    final response = await SupabaseService.client
        .from('Post')
        .select('''
          post_Id,
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(restaurant_Id, restaurant_name, categoryCuisine),
          Post_Image(image_Id, image_url)
        ''')
        .eq('user_Id', userId)
        .eq('isRemoved', false)
        .order('created_At', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new post with optional images uploaded to Supabase Storage.
  Future<String> createPost({
    required String userId,
    String? restaurantId,
    required String title,
    required String caption,
    List<Uint8List> images = const [],
  }) async {
    final postId = _generateUUID();

    // 1. Upload images natively FIRST (fail fast if any upload fails)
    final List<Map<String, dynamic>> postImageRecords = [];
    for (final bytes in images) {
      final imageId = _generateUUID();
      final path = 'posts/$postId/$imageId.jpg';

      // Upload to Storage
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

    // 2. Insert Post Row (Only happens if ALL images succeeded!)
    await SupabaseService.client.from('Post').insert({
      'post_Id': postId,
      'user_Id': userId,
      if (restaurantId != null) 'restaurant_Id': restaurantId,
      'title': title,
      'caption': caption,
      'isRemoved': false,
      'likeCount': 0,
      'saveCount': 0,
    });

    // 3. Insert Image Rows safely
    if (postImageRecords.isNotEmpty) {
      await SupabaseService.client.from('Post_Image').insert(postImageRecords);
    }

    return postId;
  }

  // NOTE: Unlike comment_repository.dart, we CANNOT delegate UUID generation to
  //       Supabase here. The postId and imageId are needed client-side BEFORE any
  //       network call because we use them to build the Storage upload path:
  //       e.g. 'posts/$postId/$imageId.jpg'.
  //       If we let Supabase auto-generate them, we'd have no path to upload to!
  //
  // TODO: One future approach is to pre-generate the path on the server (RPC function)
  //       but for now client-side generation is the correct pattern here.
  static final _secureRand = Random.secure();

  String _generateUUID() {
    final bytes = List<int>.generate(16, (_) => _secureRand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
        '-${hex.substring(20)}';
  }
  /// Toggles the like status of a post. The post likeCount is handled automatically via a backend Postgres Trigger.
  Future<void> toggleLike(String postId, String userId, bool isLiking, int newCount) async {
    if (isLiking) {
      await SupabaseService.client.from('Likes').insert({
        'post_Id': postId,
        'user_Id': userId,
      });
    } else {
      await SupabaseService.client
          .from('Likes')
          .delete()
          .eq('post_Id', postId)
          .eq('user_Id', userId);
    }
  }

  /// Checks if a post is liked by the user.
  Future<bool> checkIsLiked(String postId, String userId) async {
    final response = await SupabaseService.client
        .from('Likes')
        .select('post_Id')
        .eq('post_Id', postId)
        .eq('user_Id', userId)
        .maybeSingle();
    return response != null;
  }
}
