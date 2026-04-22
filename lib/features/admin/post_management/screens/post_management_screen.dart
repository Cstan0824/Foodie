import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/repositories/report_repository.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/data/repositories/comment_repository.dart';
import 'package:taste_spot/features/admin/screens/admin_models.dart';
import 'package:taste_spot/features/admin/post_management/screens/admin_post_review_screen.dart'
    show AdminPostReviewScreen;
import 'package:taste_spot/features/admin/post_management/screens/admin_comment_review_screen.dart'
    show AdminCommentReviewScreen;

// ── Screen ────────────────────────────────────────────────────────────────────


class PostManagementScreen extends StatefulWidget {
  const PostManagementScreen({super.key});

  @override
  State<PostManagementScreen> createState() => _PostManagementScreenState();
}

class _PostManagementScreenState extends State<PostManagementScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _tabAnim;
  final TextEditingController _searchController = TextEditingController();

  List<ReportedPost> _posts = [];
  List<ReportedComment> _comments = [];
  bool _isLoadingPosts = false;
  bool _isLoadingComments = false;
  ReportActionStatus _statusFilter = ReportActionStatus.pending;
  String _searchQuery = '';
  int _postsRequestId = 0;
  int _commentsRequestId = 0;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final requestId = ++_postsRequestId;
    final requestedStatus = _statusFilter;
    setState(() => _isLoadingPosts = true);
    try {
      final data = await ReportRepository.instance.fetchPostReports(
        status: requestedStatus,
      );
      if (mounted && requestId == _postsRequestId) {
        setState(() => _posts = data);
      }
    } catch (e) {
      debugPrint('Error fetching post reports: $e');
    } finally {
      if (mounted && requestId == _postsRequestId) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  Future<void> _fetchComments() async {
    final requestId = ++_commentsRequestId;
    final requestedStatus = _statusFilter;
    setState(() => _isLoadingComments = true);
    try {
      final data = await ReportRepository.instance.fetchCommentReports(
        status: requestedStatus,
      );
      if (mounted && requestId == _commentsRequestId) {
        setState(() => _comments = data);
      }
    } catch (e) {
      debugPrint('Error fetching comment reports: $e');
    } finally {
      if (mounted && requestId == _commentsRequestId) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabAnim.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index == _tab) return;
    setState(() => _tab = index);
    if (index == 1) {
      _tabAnim.forward();
      _fetchComments();
    } else {
      _tabAnim.reverse();
      _fetchPosts();
    }
  }

  void _setStatusFilter(ReportActionStatus? status) {
    if (status == null || status == _statusFilter) return;
    setState(() => _statusFilter = status);
    _fetchPosts();
    _fetchComments();
  }

  bool get _canModerateCurrentStatus =>
      _statusFilter == ReportActionStatus.pending;

  String get _normalizedQuery => _searchQuery.trim().toLowerCase();

  int get _postGroupCount => _groupPosts(_posts).length;
  int get _commentGroupCount => _groupComments(_comments).length;

  List<List<ReportedPost>> _groupPosts(List<ReportedPost> reports) {
    final grouped = <String, List<ReportedPost>>{};
    for (final report in reports) {
      grouped.putIfAbsent(report.postId, () => []).add(report);
    }
    return grouped.values.toList();
  }

  List<List<ReportedComment>> _groupComments(List<ReportedComment> reports) {
    final grouped = <String, List<ReportedComment>>{};
    for (final report in reports) {
      grouped.putIfAbsent(report.commentId, () => []).add(report);
    }
    return grouped.values.toList();
  }

  bool _groupMatchesPostQuery(List<ReportedPost> group) {
    final query = _normalizedQuery;
    if (query.isEmpty) return true;

    final first = group.first;
    final haystacks = <String>[
      first.postTitle,
      first.authorHandle,
      first.restaurantName,
      for (final report in group) report.reportedBy,
    ];

    return haystacks.any((value) => value.toLowerCase().contains(query));
  }

  bool _groupMatchesCommentQuery(List<ReportedComment> group) {
    final query = _normalizedQuery;
    if (query.isEmpty) return true;

    final first = group.first;
    final haystacks = <String>[
      first.postTitle,
      first.postAuthor,
      first.commentAuthor,
      first.restaurantName,
      for (final report in group) report.reportedBy,
    ];

    return haystacks.any((value) => value.toLowerCase().contains(query));
  }

  List<List<ReportedPost>> get _visiblePostGroups =>
      _groupPosts(_posts).where(_groupMatchesPostQuery).toList();

  List<List<ReportedComment>> get _visibleCommentGroups =>
      _groupComments(_comments).where(_groupMatchesCommentQuery).toList();

  Future<void> _dismissPost(String postId) async {
    try {
      await ReportRepository.instance.dismissPostReports(postId);
      setState(() => _posts.removeWhere((p) => p.postId == postId));
    } catch (e) {
      debugPrint('Error dismissing report: $e');
    }
  }

  Future<void> _blockPost(String postId) async {
    try {
      await PostRepository.instance.blockPost(postId);
      await ReportRepository.instance.markPostReportsRemoved(postId);
      if (mounted) {
        setState(() => _posts.removeWhere((p) => p.postId == postId));
      }
    } catch (e) {
      debugPrint('Error blocking post: $e');
    }
  }

  Future<void> _dismissComment(String commentId) async {
    try {
        await ReportRepository.instance.dismissCommentReports(commentId);
        setState(() => _comments.removeWhere((c) => c.commentId == commentId));
    } catch (e) {
      debugPrint('Error dismissing report: $e');
    }
  }

  Future<void> _blockComment(String commentId) async {
    try {
      await CommentRepository.instance.blockComment(commentId);
      await ReportRepository.instance.markCommentReportsRemoved(commentId);
      if (mounted) {
        setState(() => _comments.removeWhere((c) => c.commentId == commentId));
      }
    } catch (e) {
      debugPrint('Error blocking comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ──
        Container(
          color: AppColors.cardBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                child: const Text(
                  'Report Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: CupertinoSlidingSegmentedControl<ReportActionStatus>(
                  groupValue: _statusFilter,
                  backgroundColor: AppColors.surface,
                  thumbColor: AppColors.primary,
                  children: {
                    for (final status in ReportActionStatus.values)
                      status: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _statusFilter == status
                                ? CupertinoColors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                  },
                  onValueChanged: _setStatusFilter,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: _tab == 0
                      ? 'Search by post, owner, or reporter'
                      : 'Search by post, owner, or reporter',
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              // ── Animated underline tab bar ──
              _SlideTabBar(
                labels: [
                  'Posts  ${_postGroupCount > 0 ? "($_postGroupCount)" : ""}',
                  'Comments  ${_commentGroupCount > 0 ? "($_commentGroupCount)" : ""}',
                ],
                selectedIndex: _tab,
                onTap: _switchTab,
              ),
            ],
          ),
        ),

        // ── Content ──
        Expanded(
          child: _tab == 0 ? _buildPostsList() : _buildCommentsList(),
        ),
      ],
    );
  }

  Widget _buildPostsList() {
    if (_isLoadingPosts) return const Center(child: CupertinoActivityIndicator());
    final groups = _visiblePostGroups;
    if (groups.isEmpty) {
      return _EmptyState(
        icon: CupertinoIcons.doc_text,
        message: _searchQuery.isNotEmpty
            ? 'No matching post reports'
            : 'No ${_statusFilter.label.toLowerCase()} post reports',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 0),
      itemCount: groups.length,
      separatorBuilder: (context, index) =>
          Container(height: 10, color: AppColors.divider.withAlpha(60)),
      itemBuilder: (_, i) {
        final group = groups[i];
        return _ReportedPostRow(
          posts: group,
          onDismiss: _canModerateCurrentStatus
              ? () => _dismissPost(group.first.postId)
              : null,
          onBlock: _canModerateCurrentStatus
              ? () => _blockPost(group.first.postId)
              : null,
          showModerationActions: _canModerateCurrentStatus,
        );
      },
    );
  }

  Widget _buildCommentsList() {
    if (_isLoadingComments) return const Center(child: CupertinoActivityIndicator());
    final groups = _visibleCommentGroups;
    if (groups.isEmpty) {
      return _EmptyState(
        icon: CupertinoIcons.chat_bubble,
        message: _searchQuery.isNotEmpty
            ? 'No matching comment reports'
            : 'No ${_statusFilter.label.toLowerCase()} comment reports',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 0),
      itemCount: groups.length,
      separatorBuilder: (context, index) =>
          Container(height: 10, color: AppColors.divider.withAlpha(60)),
      itemBuilder: (_, i) {
        final group = groups[i];
        return _ReportedCommentRow(
          comments: group,
          onDismiss: _canModerateCurrentStatus
              ? () => _dismissComment(group.first.commentId)
              : null,
          onBlock: _canModerateCurrentStatus
              ? () => _blockComment(group.first.commentId)
              : null,
          showModerationActions: _canModerateCurrentStatus,
        );
      },
    );
  }
}

// ── Animated underline tab bar ────────────────────────────────────────────────

class _SlideTabBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _SlideTabBar({
    required this.labels,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(labels.length, (i) {
            final selected = i == selectedIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      child: Text(labels[i]),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        // Sliding underline
        LayoutBuilder(builder: (ctx, constraints) {
          final tabWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              Container(height: 1, color: AppColors.divider),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                left: tabWidth * selectedIndex,
                child: Container(
                  width: tabWidth,
                  height: 2,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ── Reported Post Row ─────────────────────────────────────────────────────────

class _ReportedPostRow extends StatelessWidget {
  final List<ReportedPost> posts;
  final VoidCallback? onDismiss;
  final VoidCallback? onBlock;
  final bool showModerationActions;

  const _ReportedPostRow({
    required this.posts,
    required this.onDismiss,
    required this.onBlock,
    required this.showModerationActions,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    final firstPost = posts.first;
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final result = await Navigator.of(context).push<ReviewResult>(
          CupertinoPageRoute(
            builder: (_) => AdminPostReviewScreen(
              posts: posts,
              showModerationActions: showModerationActions,
            ),
          ),
        );
        if (result == ReviewResult.dismiss) onDismiss?.call();
        if (result == ReviewResult.block) onBlock?.call();
      },
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Post Info ──
            Row(
              children: [
                const Icon(CupertinoIcons.doc_text, size: 16, color: AppColors.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '"${firstPost.postTitle}" by @${firstPost.authorHandle}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: firstPost.status),
                const SizedBox(width: 8),
                Text(
                  firstPost.timeAgo, // Display time of the first report logic
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // ── Report Preview Info ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withAlpha(10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF3B30).withAlpha(40), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(CupertinoIcons.flag_fill, size: 14, color: Color(0xFFFF3B30)),
                      const SizedBox(width: 6),
                      Text(
                        'Reported ${posts.length} Time${posts.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF3B30),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to review all',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Most recent reason: ${firstPost.reportReason}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grouped Reported Comments Row ─────────────────────────────────────────────

class _ReportedCommentRow extends StatelessWidget {
  final List<ReportedComment> comments;
  final VoidCallback? onDismiss;
  final VoidCallback? onBlock;
  final bool showModerationActions;

  const _ReportedCommentRow({
    required this.comments,
    required this.onDismiss,
    required this.onBlock,
    required this.showModerationActions,
  });

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) return const SizedBox.shrink();

    final firstComment = comments.first;

    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Parent Post Context ──
          Row(
            children: [
              const Icon(CupertinoIcons.doc_text, size: 16, color: AppColors.textLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'On Post: "${firstComment.postTitle}" by @${firstComment.postAuthor}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                firstComment.timeAgo, // Display time of the first report logic
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Target Comment Preview Info ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final result = await Navigator.of(context).push<ReviewResult>(
                CupertinoPageRoute(
                  builder: (_) => AdminCommentReviewScreen(
                    comments: comments,
                    showModerationActions: showModerationActions,
                  ),
                ),
              );
              if (result == ReviewResult.dismiss) onDismiss?.call();
              if (result == ReviewResult.block) onBlock?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500).withAlpha(10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF9500).withAlpha(40), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                      children: [
                        const Icon(CupertinoIcons.chat_bubble_text_fill, size: 14, color: Color(0xFFFF9500)),
                        const SizedBox(width: 6),
                        Text(
                          '@${firstComment.commentAuthor}: ',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),  
                  Text(
                    '"${firstComment.commentText}"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Container(height: 0.5, color: const Color(0xFFFF9500).withAlpha(40)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.flag_fill, size: 14, color: Color(0xFFFF3B30)),
                      const SizedBox(width: 6),
                      Text(
                        'Reported ${comments.length} Time${comments.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF3B30),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to review all',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Most recent reason: ${firstComment.reportReason}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusBadge(status: firstComment.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Shared helpers ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initial;
  final double size;
  final Color? color;

  const _Avatar({required this.initial, required this.size, this.color});

  static const List<Color> _palette = [
    Color(0xFF5856D6),
    Color(0xFF34C759),
    Color(0xFF007AFF),
    Color(0xFFFF9500),
    Color(0xFFAF52DE),
  ];

  Color _colorFor(String s) {
    final idx = s.codeUnitAt(0) % _palette.length;
    return color ?? _palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFor(initial),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
          ),
        ),
      ),
    );
  }
}

class _ReasonBadge extends StatelessWidget {
  final String reason;

  const _ReasonBadge({required this.reason});

  static Color _colorFor(String r) {
    switch (r.toLowerCase()) {
      case 'spam':
        return const Color(0xFFFF9500);
      case 'offensive language':
      case 'hate speech':
        return const Color(0xFFFF3B30);
      case 'misinformation':
      case 'false claims':
        return const Color(0xFF5856D6);
      case 'harassment':
        return const Color(0xFFFF2D55);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colorFor(reason);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withAlpha(55), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.flag_fill, size: 9, color: c),
          const SizedBox(width: 3),
          Text(
            reason,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ReportActionStatus status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case ReportActionStatus.pending:
        return const Color(0xFFFF9500);
      case ReportActionStatus.removed:
        return const Color(0xFFFF3B30);
      case ReportActionStatus.dismissed:
        return const Color(0xFF34C759);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(55), width: 0.8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _TextAction({
    required this.label,
    required this.onTap,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: destructive
              ? const Color(0xFFFF3B30)
              : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'All clear!',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
