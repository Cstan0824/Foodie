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

  List<ReportedPost> _posts = [];
  List<ReportedComment> _comments = [];
  bool _isLoadingPosts = false;
  bool _isLoadingComments = false;
  bool _hasFetchedPosts = false;
  bool _hasFetchedComments = false;

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
    if (_hasFetchedPosts) return;
    setState(() => _isLoadingPosts = true);
    try {
      final data = await ReportRepository.instance.fetchPostReports();
      if (mounted) setState(() { _posts = data; _hasFetchedPosts = true; });
    } catch (e) {
      debugPrint('Error fetching post reports: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _fetchComments() async {
    if (_hasFetchedComments) return;
    setState(() => _isLoadingComments = true);
    try {
      final data = await ReportRepository.instance.fetchCommentReports();
      if (mounted) setState(() { _comments = data; _hasFetchedComments = true; });
    } catch (e) {
      debugPrint('Error fetching comment reports: $e');
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  @override
  void dispose() {
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

  Future<void> _dismissPost(String postId) async {
    try {
      await ReportRepository.instance.dismissPostReports(postId);
      setState(() => _posts.removeWhere((p) => p.postId == postId));
    } catch (e) {
      debugPrint('Error dismissing report: $e');
    }
  }

  void _blockPost(String postId) {
    _confirm(
      title: 'Block Post',
      message: 'This post will be blocked and hidden from users.',
      label: 'Block Post',
      onConfirm: () async {
        try {
          await PostRepository.instance.blockPost(postId);
          await ReportRepository.instance.markPostReportsRemoved(postId);
          if (mounted) {
            setState(() => _posts.removeWhere((p) => p.postId == postId));
          }
        } catch (e) {
          debugPrint('Error blocking post: $e');
        }
      },
    );
  }

  Future<void> _dismissComment(String commentId) async {
    try {
        await ReportRepository.instance.dismissCommentReports(commentId);
        setState(() => _comments.removeWhere((c) => c.commentId == commentId));
    } catch (e) {
      debugPrint('Error dismissing report: $e');
    }
  }

  void _blockComment(String commentId) {
    _confirm(
      title: 'Block Comment',
      message: 'This comment will be blocked and hidden from users.',
      label: 'Block Comment',
      onConfirm: () async {
        try {
          await CommentRepository.instance.blockComment(commentId);
          await ReportRepository.instance.markCommentReportsRemoved(commentId);
          if (mounted) {
            setState(() => _comments.removeWhere((c) => c.commentId == commentId));
          }
        } catch (e) {
          debugPrint('Error blocking comment: $e');
        }
      },
    );
  }

  void _confirm({
    required String title,
    required String message,
    required String label,
    required VoidCallback onConfirm,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(label),
          ),
        ],
      ),
    );
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
                  'Post Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              // ── Animated underline tab bar ──
              _SlideTabBar(
                labels: [
                  'Posts  ${_posts.isNotEmpty ? "(${_posts.length})" : ""}',
                  'Comments  ${_comments.isNotEmpty ? "(${_comments.length})" : ""}',
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
    if (_posts.isEmpty) {
      return const _EmptyState(icon: CupertinoIcons.doc_text, message: 'No reported posts');
    }
    
    final Map<String, List<ReportedPost>> grouped = {};
    for (final p in _posts) {
      grouped.putIfAbsent(p.postId, () => []).add(p);
    }
    final keys = grouped.keys.toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 0),
      itemCount: keys.length,
      separatorBuilder: (context, index) =>
          Container(height: 10, color: AppColors.divider.withAlpha(60)),
      itemBuilder: (_, i) {
        final group = grouped[keys[i]]!;
        return _ReportedPostRow(
          posts: group,
          onDismiss: () => _dismissPost(group.first.postId),
          onBlock: () => _blockPost(group.first.postId),
        );
      },
    );
  }

  Widget _buildCommentsList() {
    if (_isLoadingComments) return const Center(child: CupertinoActivityIndicator());
    if (_comments.isEmpty) {
      return const _EmptyState(
          icon: CupertinoIcons.chat_bubble, message: 'No reported comments');
    }
    
    final Map<String, List<ReportedComment>> grouped = {};
    for (final c in _comments) {
      grouped.putIfAbsent(c.commentId, () => []).add(c);
    }
    final keys = grouped.keys.toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 0),
      itemCount: keys.length,
      separatorBuilder: (context, index) =>
          Container(height: 10, color: AppColors.divider.withAlpha(60)),
      itemBuilder: (_, i) {
        final group = grouped[keys[i]]!;
        return _ReportedCommentRow(
          comments: group,
          onDismiss: () => _dismissComment(group.first.commentId),
          onBlock: () => _blockComment(group.first.commentId),
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
  final VoidCallback onDismiss;
  final VoidCallback onBlock;

  const _ReportedPostRow({
    required this.posts,
    required this.onDismiss,
    required this.onBlock,
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
              onDismiss: onDismiss,
              onBlock: onBlock,
            ),
          ),
        );
        if (result == ReviewResult.dismiss) onDismiss();
        if (result == ReviewResult.block) onBlock();
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
  final VoidCallback onDismiss;
  final VoidCallback onBlock;

  const _ReportedCommentRow({
    required this.comments,
    required this.onDismiss,
    required this.onBlock,
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
                    onDismiss: onDismiss,
                    onBlock: onBlock,
                  ),
                ),
              );
              if (result == ReviewResult.dismiss) onDismiss();
              if (result == ReviewResult.block) onBlock();
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
