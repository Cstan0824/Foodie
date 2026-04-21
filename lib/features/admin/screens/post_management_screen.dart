import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/admin/screens/admin_models.dart';
import 'package:taste_spot/features/admin/screens/admin_post_review_screen.dart'
    show AdminPostReviewScreen;

class _ReportedComment {
  final String id;
  final String commentText;
  final String commentAuthor;
  final String commentAuthorInitial;
  final String postTitle;
  final String postAuthor;
  final String postAuthorInitial;
  final String postSnippet;
  final String reportReason;
  final String reportedBy;
  final String timeAgo;

  const _ReportedComment({
    required this.id,
    required this.commentText,
    required this.commentAuthor,
    required this.commentAuthorInitial,
    required this.postTitle,
    required this.postAuthor,
    required this.postAuthorInitial,
    required this.postSnippet,
    required this.reportReason,
    required this.reportedBy,
    required this.timeAgo,
  });
}

// ── Mock data ─────────────────────────────────────────────────────────────────

List<ReportedPost> _buildMockPosts() => const [
      ReportedPost(
        id: '1',
        postTitle: 'Best BBQ spot in Bangsar',
        authorHandle: 'foodie_kl',
        authorInitial: 'F',
        reportReason: 'Spam',
        reportedBy: '@user123',
        timeAgo: '2h ago',
        restaurantName: 'Smoke & Fire BBQ',
        postSnippet:
            'You guys HAVE to try this place, link in bio for discount code...',
      ),
      ReportedPost(
        id: '2',
        postTitle: 'Overrated ramen in KLCC',
        authorHandle: 'noodle_fan',
        authorInitial: 'N',
        reportReason: 'Misinformation',
        reportedBy: '@truefoodie',
        timeAgo: '5h ago',
        restaurantName: 'Ramen Nagi',
        postSnippet:
            'This place got a Michelin star last year which is completely false...',
      ),
      ReportedPost(
        id: '3',
        postTitle: 'Hidden gem in Petaling Jaya',
        authorHandle: 'explorer99',
        authorInitial: 'E',
        reportReason: 'Inappropriate content',
        reportedBy: '@admin_tip',
        timeAgo: '1d ago',
        restaurantName: 'Cafe Botanika',
        postSnippet:
            'Images in this post contain material that violates community guidelines.',
      ),
    ];

List<_ReportedComment> _buildMockComments() => const [
      _ReportedComment(
        id: '1',
        commentText:
            'This food is absolutely disgusting, they should close this place down. Worst experience ever, don\'t waste your money.',
        commentAuthor: 'bad_user',
        commentAuthorInitial: 'B',
        postTitle: 'Omakase at Zuma KL',
        postAuthor: 'luxefoodie',
        postAuthorInitial: 'L',
        postSnippet: 'Had the most incredible 12-course omakase last night...',
        reportReason: 'Offensive Language',
        reportedBy: '@luxefoodie',
        timeAgo: '3h ago',
      ),
      _ReportedComment(
        id: '2',
        commentText:
            'Click here for free vouchers! Limited time only. Visit bit.ly/xxx to claim now!!!',
        commentAuthor: 'spammer_bot',
        commentAuthorInitial: 'S',
        postTitle: 'Omakase at Zuma KL',
        postAuthor: 'luxefoodie',
        postAuthorInitial: 'L',
        postSnippet: 'Had the most incredible 12-course omakase last night...',
        reportReason: 'Spam',
        reportedBy: '@user444',
        timeAgo: '6h ago',
      ),
      _ReportedComment(
        id: '3',
        commentText:
            'The owner is a scammer. I paid and never got my order. Stay away from this place!!!',
        commentAuthor: 'angry_customer',
        commentAuthorInitial: 'A',
        postTitle: 'New dim sum place in Mont Kiara',
        postAuthor: 'dimsum_lover',
        postAuthorInitial: 'D',
        postSnippet: 'Finally a dim sum spot that opens until midnight in MK...',
        reportReason: 'False claims',
        reportedBy: '@dimsum_lover',
        timeAgo: '1d ago',
      ),
      _ReportedComment(
        id: '4',
        commentText:
            'Honestly this review is fake, I can tell this person was paid to write this garbage.',
        commentAuthor: 'skeptic_eater',
        commentAuthorInitial: 'S',
        postTitle: 'Best sushi I\'ve ever had!',
        postAuthor: 'sushi_star',
        postAuthorInitial: 'S',
        postSnippet:
            'Went to Nobu for my birthday dinner and it exceeded every expectation...',
        reportReason: 'Harassment',
        reportedBy: '@sushi_star',
        timeAgo: '2d ago',
      ),
    ];

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

  late final List<ReportedPost> _posts;
  late final List<_ReportedComment> _comments;

  @override
  void initState() {
    super.initState();
    _posts = List<ReportedPost>.of(_buildMockPosts());
    _comments = List<_ReportedComment>.of(_buildMockComments());
    _tabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
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
    } else {
      _tabAnim.reverse();
    }
  }

  void _dismissPost(String id) => setState(() => _posts.removeWhere((p) => p.id == id));
  void _removePost(String id) => _confirm(
        title: 'Remove Post',
        message: 'This post will be permanently deleted.',
        label: 'Remove Post',
        onConfirm: () => setState(() => _posts.removeWhere((p) => p.id == id)),
      );
  void _dismissComment(String id) =>
      setState(() => _comments.removeWhere((c) => c.id == id));
  void _removeComment(String id) => _confirm(
        title: 'Remove Comment',
        message: 'This comment will be permanently deleted.',
        label: 'Remove Comment',
        onConfirm: () => setState(() => _comments.removeWhere((c) => c.id == id)),
      );

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
    if (_posts.isEmpty) {
      return const _EmptyState(icon: CupertinoIcons.doc_text, message: 'No reported posts');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _posts.length,
      separatorBuilder: (context, index) =>
          Container(height: 0.5, color: AppColors.divider),
      itemBuilder: (_, i) => _ReportedPostRow(
        post: _posts[i],
        onDismiss: () => _dismissPost(_posts[i].id),
        onRemove: () => _removePost(_posts[i].id),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_comments.isEmpty) {
      return const _EmptyState(
          icon: CupertinoIcons.chat_bubble, message: 'No reported comments');
    }
    
    final Map<String, List<_ReportedComment>> grouped = {};
    for (final c in _comments) {
      grouped.putIfAbsent(c.postTitle, () => []).add(c);
    }
    final keys = grouped.keys.toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: keys.length,
      separatorBuilder: (context, index) =>
          Container(height: 0.5, color: AppColors.divider),
      itemBuilder: (_, i) {
        final group = grouped[keys[i]]!;
        return _GroupedReportedCommentsRow(
          comments: group,
          onDismiss: _dismissComment,
          onRemove: _removeComment,
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
  final ReportedPost post;
  final VoidCallback onDismiss;
  final VoidCallback onRemove;

  const _ReportedPostRow({
    required this.post,
    required this.onDismiss,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final result = await Navigator.of(context).push<ReviewResult>(
          CupertinoPageRoute(
            builder: (_) => AdminPostReviewScreen(
              post: post,
              onDismiss: onDismiss,
              onBlock: onRemove,
            ),
          ),
        );
        if (result == ReviewResult.dismiss) onDismiss();
        if (result == ReviewResult.block) onRemove();
      },
      child: Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(initial: post.authorInitial, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.authorHandle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'REPORTED POST',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF3B30),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          post.timeAgo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.restaurantName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.postTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      post.postSnippet,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Report info ──
          Row(
            children: [
              const SizedBox(width: 46), // align with content
              _ReasonBadge(reason: post.reportReason),
              const SizedBox(width: 8),
              Text(
                'Reported by ${post.reportedBy}',
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Actions ──
          Row(
            children: [
              const SizedBox(width: 46),
              _TextAction(label: 'Dismiss', onTap: onDismiss, destructive: false),
              const SizedBox(width: 20),
              _TextAction(label: 'Remove Post', onTap: onRemove, destructive: true),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
    ),   // closes Container
    );   // closes GestureDetector
  }
}

// ── Grouped Reported Comments Row ─────────────────────────────────────────────

class _GroupedReportedCommentsRow extends StatelessWidget {
  final List<_ReportedComment> comments;
  final Function(String) onDismiss;
  final Function(String) onRemove;

  const _GroupedReportedCommentsRow({
    required this.comments,
    required this.onDismiss,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) return const SizedBox.shrink();

    final firstComment = comments.first;
    const avatarSize = 36.0;

    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Parent post ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(initial: firstComment.postAuthorInitial, size: avatarSize),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          firstComment.postAuthor,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'REPORTED COMMENTS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF9500),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstComment.postSnippet,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstComment.postTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),

          // ── Threaded Comments ──
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: avatarSize,
                  child: Center(
                    child: Container(width: 2, color: AppColors.divider),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: comments.map((comment) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Avatar(
                                  initial: comment.commentAuthorInitial,
                                  size: 24,
                                  color: const Color(0xFFFF3B30).withAlpha(200),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  comment.commentAuthor,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  comment.timeAgo,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              comment.commentText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _ReasonBadge(reason: comment.reportReason),
                                const SizedBox(width: 8),
                                Text(
                                  'by ${comment.reportedBy}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _TextAction(
                                  label: 'Dismiss',
                                  onTap: () => onDismiss(comment.id),
                                  destructive: false,
                                ),
                                const SizedBox(width: 20),
                                _TextAction(
                                  label: 'Remove Comment',
                                  onTap: () => onRemove(comment.id),
                                  destructive: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
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
