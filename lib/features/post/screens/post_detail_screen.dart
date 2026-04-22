import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/comment_model.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/repositories/comment_repository.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/features/post/screens/edit_post_screen.dart';
import 'package:taste_spot/features/post/screens/report_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PostModel _currentPost;
  bool _wasEdited = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;
  int _currentImageIndex = 0;
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  // Comments state
  List<CommentModel> _comments = [];
  bool _isLoadingComments = true;
  bool _isPostingComment = false;

  /// Returns a human-readable relative time string from a [DateTime].
  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  // Use real image URLs from the post
  List<String> get _images => _currentPost.imageUrls.isNotEmpty
      ? _currentPost.imageUrls
      : [_currentPost.imageUrl];

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _loadComments();
    _checkLikeStatus();
  }

  Future<void> _checkLikeStatus() async {
    try {
      final isLiked = await PostRepository.instance.checkIsLiked(
        _currentPost.id,
        '00000000-0000-0000-0000-000000000001',
      );
      // Wait, if it's currently incorrectly showing '+1' locally due to initial DB sum plus the true literal, updating the model avoids this
      if (mounted) setState(() => _isLiked = isLiked);
    } catch (_) {}
  }

  bool _isLiking = false;

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);

    final newIsLiked = !_isLiked;
    final rawNewCount = _currentPost.likes + (newIsLiked ? 1 : -1);
    final newCount = rawNewCount < 0 ? 0 : rawNewCount;

    setState(() {
      _isLiked = newIsLiked;
      _currentPost = _currentPost.copyWith(likes: newCount);
      _wasEdited = true;
    });

    try {
      await PostRepository.instance.toggleLike(
        _currentPost.id,
        '00000000-0000-0000-0000-000000000001',
        newIsLiked,
      );
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _currentPost = _currentPost.copyWith(
            likes: newCount + (newIsLiked ? -1 : 1),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final comments = await CommentRepository.instance.fetchComments(
        _currentPost.id,
      );
      if (mounted) setState(() => _comments = comments);
    } catch (_) {
      // silently keep empty list on error
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPostingComment) return;

    setState(() => _isPostingComment = true);
    try {
      // TODO: replace with real auth userId when auth is implemented
      const tempUserId = '00000000-0000-0000-0000-000000000001';
      final newComment = await CommentRepository.instance.postComment(
        postId: _currentPost.id,
        userId: tempUserId,
        content: text,
      );
      if (mounted) {
        setState(() => _comments.insert(0, newComment));
        _commentController.clear();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Failed to post'),
            content: const Text('Something went wrong. Please try again.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
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
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () =>
                  Navigator.of(context).pop(_wasEdited ? true : null),
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
                _currentPost.authorAvatar,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 36,
                  height: 36,
                  color: AppColors.surface,
                  child: const Icon(
                    CupertinoIcons.person_fill,
                    color: AppColors.textLight,
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
                    _currentPost.authorName,
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
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Follow button
            GestureDetector(
              onTap: () => setState(() => _isFollowing = !_isFollowing),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isFollowing ? AppColors.surface : AppColors.primary,
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
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  _currentPost.userId == '00000000-0000-0000-0000-000000000001'
                      ? CupertinoIcons.ellipsis
                      : CupertinoIcons.arrow_turn_up_right,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
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

        // Image counter badge — only shown when there are multiple images
        if (_images.length > 1)
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentPost.title.isNotEmpty)
            Text(
              _currentPost.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          if (_currentPost.description.isNotEmpty) ...[
            if (_currentPost.title.isNotEmpty) const SizedBox(height: 8),
            Text(
              _currentPost.description,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // RESTAURANT TAG
  // ══════════════════════════════════════════
  Widget _buildRestaurantTag() {
    if (_currentPost.restaurantName.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: GestureDetector(
        onTap: () async {
          final query = Uri.encodeComponent(_currentPost.restaurantName);
          final url = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$query',
          );
          try {
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          } catch (_) {
            // Silently fail if unable to launch
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.location_solid,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                _currentPost.restaurantName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 12,
                color: AppColors.primary,
              ),
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
    final timeStr = _timeAgo(_currentPost.createdAt);
    final label = _currentPost.location != null
        ? '$timeStr · ${_currentPost.location}'
        : timeStr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Text(
        label,
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
      child: Row(
        children: [
          Text(
            _isLoadingComments
                ? 'Loading comments…'
                : '${_comments.length} Comments',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (_isLoadingComments) ...const [
            SizedBox(width: 8),
            CupertinoActivityIndicator(radius: 8),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // COMMENT TILE
  // ══════════════════════════════════════════
  Widget _buildCommentTile(CommentModel comment) {
    return GestureDetector(
      onLongPress: () => _showCommentOptions(context, comment),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Initials avatar (no image URL available from DB)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: Text(
                comment.initials,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.authorName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comment.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    comment.timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
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

  // ══════════════════════════════════════════
  // BOTTOM ACTION BAR
  // ══════════════════════════════════════════
  Widget _buildBottomBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      // Add SafeArea bottom padding if needed, or handle manually
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        bottomPadding > 0 ? bottomPadding : 10,
      ),
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
                  style: TextStyle(fontSize: 14, color: AppColors.textLight),
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
                label: _formatCount(_currentPost.likes),
                color: _isLiked ? AppColors.primary : AppColors.textSecondary,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 16),
              _ActionButton(
                icon: _isSaved
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                // Show the DB saveCount directly — no local +1 offset,
                // since _isSaved is not yet backed by a real Supabase check.
                label: _formatCount(_currentPost.saveCount),
                color: _isSaved ? AppColors.primary : AppColors.textSecondary,
                onTap: () => setState(() => _isSaved = !_isSaved),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCommentSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          color: CupertinoColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Current user avatar placeholder
                ClipOval(
                  child: Image.network(
                    'https://i.pravatar.cc/200?img=12',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoTextField(
                    controller: _commentController,
                    autofocus: true,
                    placeholder: 'Add a comment...',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.only(bottom: 8, left: 8, right: 4),
                  minimumSize: Size.zero,
                  onPressed: _submitComment,
                  child: const Text(
                    'Post',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    const currentUserId = '00000000-0000-0000-0000-000000000001';
    final isOwner = _currentPost.userId == currentUserId;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 30, top: 10),
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: isOwner
                      ? [
                          _buildHorizontalOption(
                            icon: CupertinoIcons.pencil,
                            label: 'Edit',
                            onTap: () async {
                              Navigator.pop(context);
                              final updatedPost = await Navigator.of(context)
                                  .push<PostModel>(
                                    CupertinoPageRoute(
                                      builder: (_) =>
                                          EditPostScreen(post: _currentPost),
                                    ),
                                  );
                              if (updatedPost != null && mounted) {
                                setState(() {
                                  _currentPost = updatedPost;
                                  _wasEdited = true;
                                });
                              }
                            },
                          ),
                          _buildHorizontalOption(
                            icon: CupertinoIcons.share,
                            label: 'Share',
                            onTap: () => Navigator.pop(context),
                          ),
                          _buildHorizontalOption(
                            icon: CupertinoIcons.delete,
                            label: 'Delete',
                            isDestructive: true,
                            onTap: () async {
                              Navigator.pop(context);
                              await _deletePost();
                            },
                          ),
                        ]
                      : [
                          _buildHorizontalOption(
                            icon: CupertinoIcons.bookmark,
                            label: 'Save',
                            onTap: () => Navigator.pop(context),
                          ),
                          _buildHorizontalOption(
                            icon: CupertinoIcons.share,
                            label: 'Share',
                            onTap: () => Navigator.pop(context),
                          ),
                          _buildHorizontalOption(
                            icon: CupertinoIcons.link,
                            label: 'Link',
                            onTap: () => Navigator.pop(context),
                          ),
                          _buildHorizontalOption(
                            icon: CupertinoIcons.flag,
                            label: 'Report',
                            isDestructive: true,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  fullscreenDialog: true,
                                  builder: (_) =>
                                      ReportFormScreen(post: _currentPost),
                                ),
                              );
                            },
                          ),
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentOptions(BuildContext context, CommentModel comment) {
    const currentUserId = '00000000-0000-0000-0000-000000000001';
    final isOwner = comment.userId == currentUserId;

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 30, top: 10),
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOwner)
                      _buildHorizontalOption(
                        icon: CupertinoIcons.delete,
                        label: 'Delete',
                        isDestructive: true,
                        onTap: () {
                          Navigator.pop(modalContext);
                          _deleteComment(comment);
                        },
                      )
                    else
                      _buildHorizontalOption(
                        icon: CupertinoIcons.flag,
                        label: 'Report',
                        isDestructive: true,
                        onTap: () {
                          Navigator.pop(modalContext);
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              fullscreenDialog: true,
                              builder: (_) =>
                                  ReportFormScreen(comment: comment),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? CupertinoColors.destructiveRed
        : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePost() async {
    // Show confirming dialog
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await PostRepository.instance.deletePost(_currentPost.id);
      if (mounted) {
        Navigator.pop(context, true); // true = returning from delete
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Failed to delete'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await CommentRepository.instance.deleteComment(comment.commentId);
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c.commentId == comment.commentId);
        });
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Failed to delete'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
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
