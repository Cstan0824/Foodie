// Shared data models for admin post moderation.

enum ReportActionStatus { pending, removed, dismissed }

extension ReportActionStatusX on ReportActionStatus {
  int get dbValue {
    switch (this) {
      case ReportActionStatus.pending:
        return 0;
      case ReportActionStatus.removed:
        return 1;
      case ReportActionStatus.dismissed:
        return 2;
    }
  }

  String get label {
    switch (this) {
      case ReportActionStatus.pending:
        return 'Pending';
      case ReportActionStatus.removed:
        return 'Removed';
      case ReportActionStatus.dismissed:
        return 'Dismissed';
    }
  }
}

class ReportedPost {
  final String id;
  final String postId;
  final ReportActionStatus status;
  final String postTitle;
  final String authorHandle;
  final String authorInitial;
  final String reportReason;
  final String? reportDetails;
  final String reportedBy;
  final String timeAgo;
  final String restaurantName;
  final String postSnippet;
  final List<String> postImages;

  const ReportedPost({
    required this.id,
    required this.postId,
    required this.status,
    required this.postTitle,
    required this.authorHandle,
    required this.authorInitial,
    required this.reportReason,
    this.reportDetails,
    required this.reportedBy,
    required this.timeAgo,
    required this.restaurantName,
    required this.postSnippet,
    this.postImages = const [],
  });
}

class ReportedComment {
  final String id;
  final String commentId;
  final ReportActionStatus status;
  final String commentText;
  final String commentAuthor;
  final String commentAuthorInitial;
  final String postTitle;
  final String postAuthor;
  final String postAuthorInitial;
  final String postSnippet;
  final String restaurantName;
  final List<String> postImages;
  final String reportReason;
  final String? reportDetails;
  final String reportedBy;
  final String timeAgo;

  const ReportedComment({
    required this.id,
    required this.commentId,
    required this.status,
    required this.commentText,
    required this.commentAuthor,
    required this.commentAuthorInitial,
    required this.postTitle,
    required this.postAuthor,
    required this.postAuthorInitial,
    required this.postSnippet,
    required this.restaurantName,
    this.postImages = const [],
    required this.reportReason,
    this.reportDetails,
    required this.reportedBy,
    required this.timeAgo,
  });
}

enum ReviewResult { dismiss, block }
