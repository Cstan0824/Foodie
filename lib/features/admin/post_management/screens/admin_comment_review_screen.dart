import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/admin/screens/admin_models.dart';

class AdminCommentReviewScreen extends StatefulWidget {
  final List<ReportedComment> comments;
  final VoidCallback? onDismiss;
  final VoidCallback? onBlock;

  const AdminCommentReviewScreen({
    super.key,
    required this.comments,
    this.onDismiss,
    this.onBlock,
  });

  @override
  State<AdminCommentReviewScreen> createState() => _AdminCommentReviewScreenState();
}

class _AdminCommentReviewScreenState extends State<AdminCommentReviewScreen> {
  int _currentImageIndex = 0;
  final ScrollController _scrollController = ScrollController();
  late List<ReportedComment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.comments);
  }

  @override
  void didUpdateWidget(AdminCommentReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.comments != oldWidget.comments) {
      _comments = List.from(widget.comments);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

  void _handleDismissAll() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Dismiss All Reports'),
        content: const Text(
            'All remaining reports against this comment will be dismissed.'),
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
              'Dismiss All',
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
        title: const Text('Block Comment'),
        content: const Text(
            'This comment will be blocked, hidden from users, and all its pending reports marked as removed.'),
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
            child: const Text('Block Comment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_comments.isEmpty) {
      return const CupertinoPageScaffold(
        backgroundColor: CupertinoColors.white,
        child: SizedBox.shrink(),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildAuthorHeader()),
          SliverToBoxAdapter(child: _buildImageSection()),
          SliverToBoxAdapter(child: _buildCaption()),
          SliverToBoxAdapter(child: _buildRestaurantTag()),
          SliverToBoxAdapter(child: _buildTimestamp()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(height: 0.5, color: AppColors.divider),
            ),
          ),
          if (_comments.isNotEmpty) _buildThreadedContainer(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
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

  Widget _buildAuthorHeader() {
    final comment = _comments.first;
    final avatarColor = _avatarColor(comment.postAuthorInitial);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  comment.postAuthorInitial.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    comment.postAuthor,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    comment.restaurantName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildImageSection() {
    final comment = _comments.first;
    final images = comment.postImages;

    if (images.isEmpty) {
      return SizedBox(
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
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 460,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (_, i) => Image.network(
              images[i],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface,
                child: const Center(
                  child: Icon(
                    CupertinoIcons.photo,
                    size: 48,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
          ),
        ),

        if (images.length > 1)
          Positioned(
            bottom: 12,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${images.length}',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentImageIndex == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == i
                        ? AppColors.primary
                        : CupertinoColors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCaption() {
    final comment = _comments.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.postTitle,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            comment.postSnippet,
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

  Widget _buildRestaurantTag() {
    final comment = _comments.first;
    if (comment.restaurantName.isEmpty) return const SizedBox.shrink();
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
              comment.restaurantName,
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

  Widget _buildTimestamp() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Text(
        '', // we only have comment timeAgo, so leave empty or format post time
        style: TextStyle(fontSize: 12, color: AppColors.textLight),
      ),
    );
  }

  Widget _buildThreadedContainer() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Positioned(
                  left: 17,
                  top: 34,
                  bottom: 30,
                  child: Container(
                    width: 1.5,
                    color: AppColors.divider,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildParentCommentThread(),
                    const SizedBox(height: 16),
                    ..._comments.map((report) => _buildChildReportThread(report)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCommentActionRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentActionRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 46),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _handleDismissAll,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider, width: 0.8),
                ),
                child: const Center(
                  child: Text(
                    'Dismiss',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _handleBlock,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Block Comment',
                    style: TextStyle(
                      fontSize: 14,
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

  Widget _buildParentCommentThread() {
    final comment = _comments.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _avatarColor(comment.commentAuthorInitial),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              comment.commentAuthorInitial.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.commentAuthor,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    comment.timeAgo,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                comment.commentText,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChildReportThread(ReportedComment report) {
    final color = _reasonColor(report.reportReason);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon perfectly centered over the thread line
          Container(
            width: 34, // Matches avatar width for alignment
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: CupertinoColors.white, // Covers the line behind it
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.flag_fill, size: 16, color: color),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@${report.reportedBy}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      report.timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    report.reportReason,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                if (report.reportDetails != null && report.reportDetails!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      report.reportDetails!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
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
