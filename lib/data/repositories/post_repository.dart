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
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(restaurant_Id, restaurant_name, categoryCuisine)
        ''')
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
          Restaurant(restaurant_Id, restaurant_name, categoryCuisine)
        ''')
        .eq('post_Id', postId)
        .maybeSingle();

    if (response == null) return null;
    return PostModel.fromJson(response as Map<String, dynamic>);
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
          Restaurant(restaurant_Id, restaurant_name, categoryCuisine)
        ''')
        .eq('user_Id', userId)
        .eq('isRemoved', false)
        .order('created_At', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
