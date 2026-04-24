import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository(this._supabase);

  Future<void> sendNotification({
    required String userId,
    required String content,
    String? senderId,
    String? redirectTo,
  }) async {
    try {
      await _supabase.from('Notification').insert({
        'id': const Uuid().v4(),
        'user_id': userId,
        'sender_id': senderId,
        'content': content,
        'redirect_To': redirectTo,
        'isRead': false,
        'created_At': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Fallback for missing sender_id column
      try {
        await _supabase.from('Notification').insert({
          'id': const Uuid().v4(),
          'user_id': userId,
          'content': content,
          'redirect_To': redirectTo,
          'isRead': false,
          'created_At': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
      print('[NOTIFICATION ERROR] $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotifications(String userId) async {
    try {
      // We try to join on both recipient (User) and sender (sender:sender_id)
      // Note: We use aliases to distinguish them clearly.
      final response = await _supabase
          .from('Notification')
          .select('''
            *,
            recipient:user_id(name),
            sender:sender_id(
              user_Id, 
              name, 
              UserImage(image_url)
            )
          ''')
          .eq('user_id', userId)
          .order('created_At', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Fallback for when sender_id column is completely missing from schema
      print('⚠️ Notification join on sender_id failed (likely column missing): $e');
      final response = await _supabase
          .from('Notification')
          .select('''
            *,
            User:user_id(
              user_Id, 
              name, 
              UserImage(image_url)
            )
          ''')
          .eq('user_id', userId)
          .order('created_At', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(response);
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('Notification')
          .select('id')
          .eq('user_id', userId)
          .eq('isRead', false);
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('Notification')
          .update({'isRead': true})
          .eq('user_id', userId)
          .eq('isRead', false);
    } catch (e) {
      print('❌ [NotificationRepository.markAllAsRead] ERROR: $e');
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final response = await _supabase
          .from('User')
          .select('name')
          .eq('user_Id', userId)
          .maybeSingle();
      return response?['name'] ?? 'Someone';
    } catch (_) {
      return 'Someone';
    }
  }

  Future<void> notifyLike({
    required String likerId,
    required String postOwnerId,
    required String postId,
  }) async {
    if (likerId == postOwnerId) return;

    final likerName = await _getUserName(likerId);
    await sendNotification(
      userId: postOwnerId,
      senderId: likerId,
      content: '$likerName liked your post',
      redirectTo: 'post:$postId',
    );
  }

  Future<void> notifyComment({
    required String commenterId,
    required String postOwnerId,
    required String postId,
    required String commentSnippet,
  }) async {
    if (commenterId == postOwnerId) return;

    final commenterName = await _getUserName(commenterId);
    final snippet = commentSnippet.length > 30 
        ? '${commentSnippet.substring(0, 27)}...' 
        : commentSnippet;

    await sendNotification(
      userId: postOwnerId,
      senderId: commenterId,
      content: '$commenterName commented: "$snippet"',
      redirectTo: 'post:$postId',
    );
  }

  Future<void> notifyCollectionShare({
    required String sharerId,
    required String targetUserId,
    required String collectionId,
    required String collectionName,
  }) async {
    if (sharerId == targetUserId) return;

    final sharerName = await _getUserName(sharerId);
    await sendNotification(
      userId: targetUserId,
      senderId: sharerId,
      content: '$sharerName shared the collection "$collectionName" with you',
      redirectTo: 'collection:$collectionId',
    );
  }
}
