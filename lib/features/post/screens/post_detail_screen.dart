import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/post_model.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;
  int _currentImageIndex = 0;
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  // Mock comments
  final _comments = [
    _CommentData(
      avatar: 'https://i.pravatar.cc/100?img=10',
      username: 'foodlover_kl',
      text: 'This place is amazing!! I went last week 😍',
      time: '2h ago',
      likes: 24,
    ),
    _CommentData(
      avatar: 'https://i.pravatar.cc/100?img=11',
      username: 'eateverywhere',
      text: 'The sambal is so good omg 🌶️ must try!!',
      time: '3h ago',
      likes: 18,
    ),
    _CommentData(
      avatar: 'https://i.pravatar.cc/100?img=12',
      username: 'penangfoodie',
      text: 'Been here 3 times already, never disappoints 👌',
      time: '5h ago',
      likes: 42,
    ),
    _CommentData(
      avatar: 'https://i.pravatar.cc/100?img=13',
      username: 'klhawker',
      text: 'How much is it per person?',
      time: '6h ago',
      likes: 3,
    ),
    _CommentData(
      avatar: 'https://i.pravatar.cc/100?img=14',
      username: 'foodhunter99',
      text: 'Just went today and it was fully packed! Queue for 30 mins but worth it 🔥',
      time: '8h ago',
      likes: 67,
    ),
  ];

  // Mock multiple images for the post
  List<String> get _images => [
        widget.post.imageUrl,
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600',
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600',
      ];

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: Stack(
        children: [
          // ── Main scrollable content ──
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Moved profile section to the top (above image)
              // Removed fixed top spacing since we're handling it in the header now
              SliverToBoxAdapter(child: _buildAuthorHeader()),
              SliverToBoxAdapter(child: _buildImageSection()),
              SliverToBoxAdapter(child: _buildCaption()),
              SliverToBoxAdapter(child: _buildRestaurantTag()),
              SliverToBoxAdapter(child: _buildTimestamp()),
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 6,
                  child: ColoredBox(color: Color(0xFFF0F0F0)),
                ),
              ),
              SliverToBoxAdapter(child: _buildCommentsHeader()),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildCommentTile(_comments[i]),
                  childCount: _comments.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),

          // ── Fixed bottom action bar ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(context),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // AUTHOR HEADER (Moved from Image Overlay)
  // ══════════════════════════════════════════
  Widget _buildAuthorHeader() {
    // Add top padding to account for status bar since we moved it out of overlay
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(
                CupertinoIcons.chevron_back,
                color: AppColors.textPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 8), // Spacing between back button and avatar

            // Avatar
            ClipOval(
              child: Image.network(
                widget.post.authorAvatar,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 36,
                  height: 36,
                  color: AppColors.surface,
                  child: const Icon(CupertinoIcons.person_fill,
                      color: AppColors.textLight),
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
                    widget.post.authorName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Food Explorer 🍜',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            // Follow button
            GestureDetector(
              onTap: () => setState(() => _isFollowing = !_isFollowing),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _isFollowing
                      ? AppColors.surface
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  border: _isFollowing
                      ? Border.all(color: AppColors.divider, width: 0.8)
                      : null,
                ),
                child: Text(
                  _isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isFollowing
                        ? AppColors.textPrimary
                        : CupertinoColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
             GestureDetector(
              onTap: () => _showMoreOptions(context),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(CupertinoIcons.ellipsis, size: 20, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // IMAGE CAROUSEL
  // ══════════════════════════════════════════
  Widget _buildImageSection() {
    return Stack(
      children: [
        SizedBox(
          height: 460,
          child: PageView.builder(
            itemCount: _images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (_, i) => Image.network(
              _images[i],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.surface,
                child: const Center(
                  child: Icon(CupertinoIcons.photo,
                      size: 48, color: AppColors.textLight),
                ),
              ),
            ),
          ),
        ),

        // Image counter badge
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
              '${_currentImageIndex + 1}/${_images.length}',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // Page dots
        Positioned(
          bottom: 16, // Adjusted bottom padding since author row is gone
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _images.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentImageIndex == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentImageIndex == i
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  // CAPTION
  // ══════════════════════════════════════════
  Widget _buildCaption() {
    const fullText =
        'Honestly one of the best spots in KL right now 🔥 The food here is absolutely incredible — every dish is packed with flavor and the portions are generous. Perfect for a family meal or date night. Highly recommend the signature dishes! Don\'t forget to come early because it gets super packed during dinner time. The ambiance is also really cozy and perfect for photos 📸 #foodi #klfood #malaysianfood #foodreview';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.post.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          // Directly showing full text
           const Text(
            fullText,
            style: TextStyle(
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
  // RESTAURANT TAG
  // ══════════════════════════════════════════
  Widget _buildRestaurantTag() {
    if (widget.post.restaurantName.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      ),
    );
  }

  // ══════════════════════════════════════════
  // TIMESTAMP
  // ══════════════════════════════════════════
  Widget _buildTimestamp() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Text(
        widget.post.location != null
            ? '2 hours ago · ${widget.post.location}'
            : '2 hours ago',
        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
      ),
    );
  }

  // ══════════════════════════════════════════
  // COMMENTS HEADER
  // ══════════════════════════════════════════
  Widget _buildCommentsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Text(
        '${_comments.length} Comments',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // COMMENT TILE
  // ══════════════════════════════════════════
  Widget _buildCommentTile(_CommentData comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.network(
              comment.avatar,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(width: 32, height: 32, color: AppColors.surface),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.username,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(comment.time,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textLight)),
                    const SizedBox(width: 16),
                    const Text('Reply',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () {},
                child: const Icon(CupertinoIcons.heart,
                    size: 16, color: AppColors.textLight),
              ),
              Text(
                '${comment.likes}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // BOTTOM ACTION BAR
  // ══════════════════════════════════════════
  Widget _buildBottomBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      // Add SafeArea bottom padding if needed, or handle manually
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottomPadding > 0 ? bottomPadding : 10),
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
          // Comment input — Takes available space
          Expanded(
            child: GestureDetector(
              onTap: () => _showCommentSheet(context),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Add a comment...',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textLight),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),

          // Action icons - Grouped tighter
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: _isLiked
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                label: _formatCount(
                    widget.post.likes + (_isLiked ? 1 : 0)),
                color: _isLiked
                    ? AppColors.primary
                    : AppColors.textSecondary,
                onTap: () => setState(() => _isLiked = !_isLiked),
              ),
              const SizedBox(width: 16),
              _ActionButton(
                icon: _isSaved
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                label: _formatCount(
                    widget.post.saveCount + (_isSaved ? 1 : 0)),
                color: _isSaved
                    ? AppColors.primary
                    : AppColors.textSecondary,
                onTap: () => setState(() => _isSaved = !_isSaved),
              ),
              const SizedBox(width: 16),
               _ActionButton(
                icon: CupertinoIcons.share,
                label: 'Share',
                color: AppColors.textSecondary,
                onTap: () {},
              )
            ],
          ),
        ],
      ),
    );
  }

  void _showCommentSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 320,
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Add Comment',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoTextField(
                controller: _commentController,
                autofocus: true,
                placeholder: 'Write a comment...',
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    _commentController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Post Comment'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save Post'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Share Post'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Copy Link'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Report'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _CommentData {
  final String avatar;
  final String username;
  final String text;
  final String time;
  final int likes;

  const _CommentData({
    required this.avatar,
    required this.username,
    required this.text,
    required this.time,
    required this.likes,
  });
}
