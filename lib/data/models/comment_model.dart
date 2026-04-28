import 'package:taste_spot/core/utils/app_time.dart';

class CommentModel {
  final String commentId;
  final String postId;
  final String userId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // Joined User table — disambiguated FK
    final user =
        (json['User'] ??
                json['User:user_Id'] ??
                json['User:User!Comment_user_Id_fkey'] ??
                json['User!Comment_user_Id_fkey'] ??
                json['sender'])
            as Map<String, dynamic>?;
    final authorName = (user?['name'] as String?) ?? 'Unknown';

    // Parse avatar URL from UserImage join (robust parsing)
    String? authorAvatar;
    if (user != null) {
      final userImages = (user['UserImage'] ?? user['user_images']);
      if (userImages != null) {
        if (userImages is List && userImages.isNotEmpty) {
          authorAvatar = userImages[0]['image_url'] as String?;
        } else if (userImages is Map) {
          authorAvatar = userImages['image_url'] as String?;
        }
      }
    }

    // Default avatar if none exists
    authorAvatar ??=
        'https://ctaxmblonofmfsyvlbsh.supabase.co/storage/v1/object/public/user_images/avatars/default_avatar.png';

    return CommentModel(
      commentId:
          json['comment_Id'] as String? ?? json['comment_id'] as String? ?? '',
      postId: json['post_Id'] as String? ?? json['post_id'] as String? ?? '',
      userId: json['user_Id'] as String? ?? json['user_id'] as String? ?? '',
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: json['content'] as String? ?? '',
      createdAt: AppTime.parseUtc(json['created_At']) ?? AppTime.nowUtc(),
    );
  }

  /// Returns a human-friendly relative time string (e.g. "2h ago", "just now").
  String get timeAgo {
    final diff = AppTime.differenceFromNowGmt8(createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return AppTime.formatShortMonthDay(createdAt);
  }

  /// Returns initials for the avatar placeholder (e.g. "Sarah Lim" → "SL").
  String get initials {
    if (authorName.isEmpty) return '?';
    final parts = authorName.trim().split(' ');
    if (parts.length >= 2) {
      if (parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
    }
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
