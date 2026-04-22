import 'dart:math'; // TODO: will be removed once UUID generation is delegated to Supabase

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
    final commentId =
        _generateUUID(); // TODO: will be removed — delegate UUID to Supabase later
    await SupabaseService.client.from('Comment').insert({
      'comment_Id': commentId,
      'post_Id': postId,
      'user_Id': userId,
      'content': content,
    });

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
        .eq('comment_Id', commentId)
        .single();

    return CommentModel.fromJson(response);
  }

  /// Submits a report for a comment.
  Future<void> reportComment({
    required String commentId,
    required String userId,
    required String reason,
    String? details,
  }) async {
    try {
      await SupabaseService.client.from('Report').insert({
        'comment_Id': commentId,
        'user_Id': userId,
        'reason': reason,
        'details': details,
        'status': 0,
      });
    } catch (e) {
      if (e.toString().contains('23505') ||
          e.toString().contains('duplicate key')) {
        throw Exception('You have already reported this comment.');
      }
      if (e.toString().contains('Users cannot report their own comments')) {
        throw Exception('You cannot report your own comment.');
      }
      rethrow;
    }
  }

  /// Deletes a comment permanently from the database.
  Future<void> deleteComment(String commentId) async {
    await SupabaseService.client
        .from('Comment')
        .delete()
        .eq('comment_Id', commentId);
  }

  // TODO: will be removed — delegate UUID generation to Supabase
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
}
