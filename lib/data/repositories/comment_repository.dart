import 'dart:math';

import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/comment_model.dart';
import 'package:taste_spot/data/repositories/repository_support.dart';

const String _commentSelect = '''
  comment_Id,
  post_Id,
  user_Id,
  content,
  created_At,
  User!Comment_user_Id_fkey(user_Id, name)
''';

class CommentRepository {
  CommentRepository._();
  static final CommentRepository instance = CommentRepository._();

  /// Fetches all visible comments for a given post, newest first.
  Future<List<CommentModel>> fetchComments(String postId) async {
    await ensurePostAvailable(
      postId,
      errorMessage: 'This post is no longer available.',
    );

    final response = await SupabaseService.client
        .from('Comment')
        .select(_commentSelect)
        .eq('post_Id', postId)
        .eq('isBlocked', false)
        .order('created_At', ascending: false);

    return (response as List<dynamic>)
        .map((row) => CommentModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Inserts a new comment for a post.
  ///
  /// Temporary testing choice: this still generates the comment UUID client-side
  /// so the created ID is known immediately during tests. Long term this should
  /// use a Supabase-generated UUID.
  Future<CommentModel> postComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    await ensurePostAvailable(
      postId,
      errorMessage: 'This post is no longer available.',
    );

    final commentId = _generateUUID();
    await SupabaseService.client.from('Comment').insert({
      'comment_Id': commentId,
      'post_Id': postId,
      'user_Id': userId,
      'content': content,
    });

    final response = await SupabaseService.client
        .from('Comment')
        .select(_commentSelect)
        .eq('comment_Id', commentId)
        .single();

    return CommentModel.fromJson(response);
  }

  Future<CommentModel> updateComment({
    required String commentId,
    required String userId,
    required String content,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw Exception('Comment cannot be empty.');
    }

    final commentRow = await SupabaseService.client
        .from('Comment')
        .select('comment_Id, post_Id, user_Id, isBlocked')
        .eq('comment_Id', commentId)
        .maybeSingle();

    if (commentRow == null || commentRow['isBlocked'] == true) {
      throw Exception('This comment is no longer available.');
    }

    final ownerId = commentRow['user_Id']?.toString();
    final postId = commentRow['post_Id']?.toString();
    if (ownerId == null || ownerId != userId) {
      throw Exception('You can only edit your own comment.');
    }
    if (postId == null || postId.isEmpty) {
      throw Exception('This comment is no longer available.');
    }

    await ensurePostAvailable(
      postId,
      errorMessage: 'This post is no longer available.',
    );

    final response = await SupabaseService.client
        .from('Comment')
        .update({'content': trimmedContent})
        .eq('comment_Id', commentId)
        .eq('user_Id', userId)
        .eq('isBlocked', false)
        .select(_commentSelect)
        .maybeSingle();

    if (response == null) {
      throw Exception('This comment is no longer available.');
    }

    return CommentModel.fromJson(response);
  }

  Future<void> reportComment({
    required String commentId,
    required String userId,
    required String reason,
    String? details,
  }) async {
    final postId = await _fetchActiveCommentPostId(commentId);
    await ensurePostAvailable(
      postId,
      errorMessage: 'This comment is no longer available.',
    );

    try {
      await SupabaseService.client.from('Report').insert({
        'comment_Id': commentId,
        'user_Id': userId,
        'reason': reason,
        'details': details,
        'status': 0,
      });
    } catch (e) {
      final message = e.toString();
      if (message.contains('23505') || message.contains('duplicate key')) {
        throw Exception('You have already reported this comment.');
      }
      if (message.contains('Users cannot report their own comments')) {
        throw Exception('You cannot report your own comment.');
      }
      rethrow;
    }
  }

  Future<void> blockComment(String commentId) async {
    final response = await SupabaseService.client
        .from('Comment')
        .update({'isBlocked': true})
        .eq('comment_Id', commentId)
        .select('comment_Id')
        .maybeSingle();

    if (response == null) {
      throw Exception('This comment is no longer available.');
    }
  }

  Future<void> deleteComment(String commentId) async {
    await SupabaseService.client
        .from('Comment')
        .delete()
        .eq('comment_Id', commentId);
  }

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

  Future<String> _fetchActiveCommentPostId(String commentId) async {
    final response = await SupabaseService.client
        .from('Comment')
        .select('post_Id')
        .eq('comment_Id', commentId)
        .eq('isBlocked', false)
        .maybeSingle();

    final postId = response?['post_Id']?.toString();
    if (postId == null || postId.isEmpty) {
      throw Exception('This comment is no longer available.');
    }

    return postId;
  }
}
