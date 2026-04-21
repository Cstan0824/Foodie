import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/admin/screens/admin_models.dart';

class AdminPostReviewScreen extends StatefulWidget {
  final ReportedPost post;
  final VoidCallback? onDismiss;
  final VoidCallback? onBlock;

  const AdminPostReviewScreen({
    super.key,
    required this.post,
    this.onDismiss,
    this.onBlock,
  });

  @override
  State<AdminPostReviewScreen> createState() => _AdminPostReviewScreenState();
}

class _AdminPostReviewScreenState extends State<AdminPostReviewScreen> {
  int _currentImageIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── helpers ──

  Color _reasonColor(String r) {
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

  static const List<Color> _avatarPalette = [
    Color(0xFF5856D6),
    Color(0xFF34C759),
    Color(0xFF007AFF),
    Color(0xFFFF9500),
    Color(0xFFAF52DE),
  ];

  Color _avatarColor(String initial) =>
      _avatarPalette[initial.codeUnitAt(0) % _avatarPalette.length];

  // ── actions ──

  void _handleDismiss() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Dismiss Report'),
        content: const Text(
            'This report will be marked as resolved and removed from the queue.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, ReviewResult.dismiss);
            },
            child: const Text(
              'Dismiss',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _handleBlock() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Block Post'),
        content: const Text(
            'This post will be hidden from all users. This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, ReviewResult.block);
            },
            child: const Text('Block Post'),
          ),
        ],
      ),
    );
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildAuthorHeader()),
              SliverToBoxAdapter(child: _buildImageSection()),
              SliverToBoxAdapter(child: _buildCaption()),
              SliverToBoxAdapter(child: _buildRestaurantTag()),
              SliverToBoxAdapter(child: _buildTimestamp()),
              SliverToBoxAdapter(child: _buildReportBanner()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // ── Fixed bottom admin bar ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildAdminBottomBar(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // AUTHOR HEADER  (mirrors PostDetailScreen)
  // ══════════════════════════════════════════
  Widget _buildAuthorHeader() {
    final avatarColor = _avatarColor(widget.post.authorInitial);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Back button
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(
                CupertinoIcons.chevron_back,
                color: AppColors.textPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 8),

            // Avatar — initial-based (no URL in mock)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.post.authorInitial.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.post.authorHandle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    widget.post.restaurantName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),

            // Admin badge — replaces Follow button
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider, width: 0.8),
              ),
              child: const Text(
                'Admin Review',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // IMAGE SECTION  (mirrors PostDetailScreen)
  // ══════════════════════════════════════════
  Widget _buildImageSection() {
    // Mock: single placeholder image panel
    return Stack(
      children: [
        SizedBox(
          height: 460,
          child: Container(
            color: AppColors.surface,
            child: const Center(
              child: Icon(
                CupertinoIcons.photo,
                size: 52,
                color: AppColors.textLight,
              ),
            ),
          ),
        ),
        // Dot indicator (single dot for mock)
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 16,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  // CAPTION  (mirrors PostDetailScreen)
  // ══════════════════════════════════════════
  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.post.postTitle,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.post.postSnippet,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // RESTAURANT TAG  (mirrors PostDetailScreen)
  // ══════════════════════════════════════════
  Widget _buildRestaurantTag() {
    if (widget.post.restaurantName.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.location_solid,
                size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              widget.post.restaurantName,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_right,
                size: 12, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // TIMESTAMP  (mirrors PostDetailScreen)
  // ══════════════════════════════════════════
  Widget _buildTimestamp() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Text(
        widget.post.timeAgo,
        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
      ),
    );
  }

  // ══════════════════════════════════════════
  // REPORT BANNER  (admin-only addition)
  // ══════════════════════════════════════════
  Widget _buildReportBanner() {
    final color = _reasonColor(widget.post.reportReason);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(55), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.flag_fill, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.reportReason,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reported by ${widget.post.reportedBy}  ·  ${widget.post.timeAgo}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // ADMIN BOTTOM BAR  (replaces normal bar)
  // ══════════════════════════════════════════
  Widget _buildAdminBottomBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
          14, 10, 14, bottomPadding > 0 ? bottomPadding : 10),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Dismiss — outline
          Expanded(
            child: GestureDetector(
              onTap: _handleDismiss,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.divider, width: 1),
                ),
                child: const Center(
                  child: Text(
                    'Dismiss',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Block Post — filled red
          Expanded(
            child: GestureDetector(
              onTap: _handleBlock,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B30).withAlpha(55),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Block Post',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
