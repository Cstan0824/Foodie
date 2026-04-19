import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/comment_model.dart';

class CommentRepository {
  CommentRepository._();
  static final CommentRepository instance = CommentRepository._();

  /// Fetches all comments for a given post, newest first.
  /// Joins User table to get the author's name.
  Future<List<CommentModel>> fetchComments(String postId) async {
    final response = await SupabaseService.client
        .from('Comment')
        .select('''
          comment_Id,
          post_Id,
          user_Id,
          content,
          created_At,
          User!Comment_user_Id_fkey(user_Id, name)
        ''')
        .eq('post_Id', postId)
        .order('created_At', ascending: false);

    return (response as List<dynamic>)
        .map((row) => CommentModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Inserts a new comment for a post.
  /// Returns the created [CommentModel] on success.
  Future<CommentModel> postComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    final response = await SupabaseService.client
        .from('Comment')
        .insert({
          'post_Id': postId,
          'user_Id': userId,
          'content': content,
        })
        .select('''
          comment_Id,
          post_Id,
          user_Id,
          content,
          created_At,
          User!Comment_user_Id_fkey(user_Id, name)
        ''')
        .single();

    return CommentModel.fromJson(response);
  }
}
