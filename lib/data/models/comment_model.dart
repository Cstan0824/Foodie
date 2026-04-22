

class CommentModel {
  final String commentId;
  final String postId;
  final String userId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // Joined User table — disambiguated FK
    final user = (json['User!Comment_user_Id_fkey'] ?? json['User']) as Map<String, dynamic>?;
    final authorName = (user?['name'] as String?) ?? 'Unknown';

    return CommentModel(
      commentId: json['comment_Id'] as String,
      postId: json['post_Id'] as String,
      userId: json['user_Id'] as String? ?? '',
      authorName: authorName,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_At'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Returns a human-friendly relative time string (e.g. "2h ago", "just now").
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${createdAt.day} ${months[createdAt.month - 1]}';

  }

  /// Returns initials for the avatar placeholder (e.g. "Sarah Lim" → "SL").
  String get initials {
    final parts = authorName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
