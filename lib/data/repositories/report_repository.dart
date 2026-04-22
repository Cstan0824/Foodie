import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/features/admin/screens/admin_models.dart';

class ReportRepository {
  ReportRepository._();
  static final instance = ReportRepository._();

  static const int _removedStatus = 1;
  static const int _dismissedStatus = 2;

  String _formatTimeAgo(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return 'Recently';
    }
  }

  ReportActionStatus _statusFromDbValue(dynamic rawStatus) {
    switch ((rawStatus as num?)?.toInt()) {
      case _removedStatus:
        return ReportActionStatus.removed;
      case _dismissedStatus:
        return ReportActionStatus.dismissed;
      case 0:
      default:
        return ReportActionStatus.pending;
    }
  }

  Future<List<ReportedPost>> fetchPostReports({
    ReportActionStatus status = ReportActionStatus.pending,
  }) async {
    final response = await SupabaseService.client
        .from('Report')
        .select('''
          id:report_Id,
          status,
          reason,
          details,
          created_At,
          User!Report_user_Id_fkey(name),
          Post!Report_post_Id_fkey!inner(
            post_Id,
            title,
            caption,
            User!Post_user_Id_fkey(name),
            Restaurant(restaurant_name),
            Post_Image(image_url)
          )
        ''')
        .isFilter('comment_Id', null)
        .eq('status', status.dbValue)
        .order('created_At', ascending: false);

    return (response as List<dynamic>).map((r) {
      final post = r['Post'] as Map<String, dynamic>;
      final rUser = r['User'] as Map<String, dynamic>?;
      final pUser = post['User'] as Map<String, dynamic>?;
      final rest = post['Restaurant'] as Map<String, dynamic>?;
      
      final authorName = pUser?['name']?.toString() ?? 'Unknown';
      final reporterName = rUser?['name']?.toString() ?? 'Someone';

      return ReportedPost(
        id: r['id']?.toString() ?? '',
        postId: post['post_Id']?.toString() ?? '',
        status: _statusFromDbValue(r['status']),
        postTitle: post['title']?.toString() ?? 'Untitled Post',
        authorHandle: authorName,
        authorInitial: authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
        reportReason: r['reason']?.toString() ?? 'Reported',
        reportDetails: r['details']?.toString(),
        reportedBy: reporterName,
        timeAgo: _formatTimeAgo(r['created_At']?.toString() ?? ''),
        restaurantName: rest?['restaurant_name']?.toString() ?? 'Unknown Restaurant',
        postSnippet: post['caption']?.toString() ?? '',
        postImages: _parsePostImages(post),
      );
    }).toList();
  }

  Future<List<ReportedComment>> fetchCommentReports({
    ReportActionStatus status = ReportActionStatus.pending,
  }) async {
    final response = await SupabaseService.client
        .from('Report')
        .select('''
          id:report_Id,
          status,
          reason,
          details,
          created_At,
          User!Report_user_Id_fkey(name),
          Comment!Report_comment_Id_fkey!inner(
            comment_Id,
            content,
            User!Comment_user_Id_fkey(name),
            Post:post_Id(
              title,
              caption,
              User!Post_user_Id_fkey(name),
              Restaurant(restaurant_name),
              Post_Image(image_url)
            )
          )
        ''')
        .not('comment_Id', 'is', null)
        .eq('status', status.dbValue)
        .order('created_At', ascending: false);

    return (response as List<dynamic>).map((r) {
      final comment = r['Comment'] as Map<String, dynamic>;
      final post = comment['Post'] as Map<String, dynamic>?;
      final rUser = r['User'] as Map<String, dynamic>?;
      final cUser = comment['User'] as Map<String, dynamic>?;
      final pUser = post?['User'] as Map<String, dynamic>?;

      final commentAuthor = cUser?['name']?.toString() ?? 'Unknown';
      final postAuthor = pUser?['name']?.toString() ?? 'Unknown';
      final reporterName = rUser?['name']?.toString() ?? 'Someone';
      
      final rest = post?['Restaurant'] as Map<String, dynamic>?;
      
      return ReportedComment(
        id: r['id']?.toString() ?? '',
        commentId: comment['comment_Id']?.toString() ?? '',
        status: _statusFromDbValue(r['status']),
        commentText: comment['content']?.toString() ?? '',
        commentAuthor: commentAuthor,
        commentAuthorInitial: commentAuthor.isNotEmpty ? commentAuthor[0].toUpperCase() : '?',
        postTitle: post?['title']?.toString() ?? 'Untitled',
        postAuthor: postAuthor,
        postAuthorInitial: postAuthor.isNotEmpty ? postAuthor[0].toUpperCase() : '?',
        postSnippet: post?['caption']?.toString() ?? '',
        restaurantName: rest?['restaurant_name']?.toString() ?? '',
        postImages: _parsePostImages(post),
        reportReason: r['reason']?.toString() ?? 'Reported',
        reportDetails: r['details']?.toString(),
        reportedBy: reporterName,
        timeAgo: _formatTimeAgo(r['created_At']?.toString() ?? ''),
      );
    }).toList();
  }

  Future<void> dismissPostReports(String postId) async {
    await SupabaseService.client
        .from('Report')
        .update({'status': _dismissedStatus})
        .eq('post_Id', postId)
        .isFilter('comment_Id', null)
        .eq('status', ReportActionStatus.pending.dbValue);
  }

  Future<void> dismissCommentReports(String commentId) async {
    await SupabaseService.client
        .from('Report')
        .update({'status': _dismissedStatus})
        .eq('comment_Id', commentId)
        .eq('status', ReportActionStatus.pending.dbValue);
  }

  Future<void> markPostReportsRemoved(String postId) async {
    await SupabaseService.client
        .from('Report')
        .update({'status': _removedStatus})
        .eq('post_Id', postId)
        .isFilter('comment_Id', null)
        .eq('status', ReportActionStatus.pending.dbValue);
  }

  Future<void> markCommentReportsRemoved(String commentId) async {
    await SupabaseService.client
        .from('Report')
        .update({'status': _removedStatus})
        .eq('comment_Id', commentId)
        .eq('status', ReportActionStatus.pending.dbValue);
  }

  List<String> _parsePostImages(Map<String, dynamic>? post) {
    final rawImages = post?['Post_Image'] as List<dynamic>? ?? [];
    final parsedImages = <String>[];
    for (final img in rawImages) {
      if (img != null && img is Map && img['image_url'] != null) {
        parsedImages.add(img['image_url'].toString());
      }
    }
    return parsedImages;
  }
}
