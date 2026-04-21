// Shared data models for admin post moderation.

class ReportedPost {
  final String id;
  final String postTitle;
  final String authorHandle;
  final String authorInitial;
  final String reportReason;
  final String reportedBy;
  final String timeAgo;
  final String restaurantName;
  final String postSnippet;

  const ReportedPost({
    required this.id,
    required this.postTitle,
    required this.authorHandle,
    required this.authorInitial,
    required this.reportReason,
    required this.reportedBy,
    required this.timeAgo,
    required this.restaurantName,
    required this.postSnippet,
  });
}

enum ReviewResult { dismiss, block }
