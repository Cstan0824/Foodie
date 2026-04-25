import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/utils/hashtag_utils.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/models/comment_model.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/repositories/comment_repository.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/data/repositories/collection_repository.dart';
import 'package:taste_spot/data/repositories/profile_repository.dart';
import 'package:taste_spot/data/models/collection_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/features/post/screens/edit_post_screen.dart';
import 'package:taste_spot/features/profile/screens/profile_screen.dart';
import 'package:taste_spot/features/restaurant/screens/restaurant_detail_screen.dart';
import 'package:taste_spot/features/post/screens/report_form_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  final bool archived;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.archived = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  static final RegExp _captionHashtagPattern = RegExp(r'#[a-zA-Z0-9_]+');
  static final RegExp _captionWhitespacePattern = RegExp(r'\s');
late PostModel _currentPost;
bool _wasEdited = false;
bool _isLiked = false;
bool _isSaved = false;
bool _isFollowing = false;
Set<String> _savedInCollectionIds = {};
bool _isFollowUpdating = false;

int _currentImageIndex = 0;
final _commentController = TextEditingController();
final _scrollController = ScrollController();

  // Comments state
  List<CommentModel> _comments = [];
  bool _isLoadingComments = true;
  bool _isPostingComment = false;
  CommentModel? _editingComment;
  String? _currentUserAvatar;

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

  String? get _currentUserId => SupabaseService.currentUserId;
  bool get _isArchivedView => widget.archived;

  bool get _isCurrentUserPostOwner =>
      _currentUserId != null && _currentPost.userId == _currentUserId;

  void _showAuthRequiredDialog() {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Sign In Required'),
        content: const Text('Please sign in to continue.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    if (!_isArchivedView) {
      _loadComments();
      _checkLikeStatus();
      _checkSaveStatus();
      _checkFollowStatus();
      _loadSaveCount();
      _fetchCurrentUserAvatar();
    } else {
      _isLoadingComments = false;
    }
  }

  Future<void> _fetchCurrentUserAvatar() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final repo = ProfileRepository(Supabase.instance.client);
      final avatarUrl = await repo.getProfileImageUrl(userId);
      if (mounted) setState(() => _currentUserAvatar = avatarUrl);
    } catch (_) {}
  }

  Future<void> _loadSaveCount() async {
    try {
      final collectionRepo = CollectionRepository(Supabase.instance.client);
      final count = await collectionRepo.getPostSaveCount(_currentPost.id);
      if (mounted) {
        setState(() {
          _currentPost = _currentPost.copyWith(saveCount: count);
        });
      }
    } catch (_) {}
  }

  Future<void> _checkFollowStatus() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null || currentUserId == _currentPost.userId) {
        if (mounted) setState(() => _isFollowing = false);
        return;
      }

      final profileRepo = ProfileRepository(Supabase.instance.client);
      final isFollowing = await profileRepo.checkIsFollowing(
        followerId: currentUserId,
        followingId: _currentPost.userId,
      );

      if (mounted) setState(() => _isFollowing = isFollowing);
    } catch (e) {
      print('[FOLLOW CHECK ERROR] $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowUpdating) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == _currentPost.userId) return;

    final nextState = !_isFollowing;
    setState(() {
      _isFollowUpdating = true;
      _isFollowing = nextState;
    });

    final profileRepo = ProfileRepository(Supabase.instance.client);
    try {
      await profileRepo.setFollowing(
        followerId: currentUserId,
        followingId: _currentPost.userId,
        isFollowing: nextState,
      );
      _wasEdited = true;
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = !nextState);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowUpdating = false;
        });
      }
    }
  }

  Future<void> _checkSaveStatus() async {
    try {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) return;

      // Get all collections that contain this post
      final response = await Supabase.instance.client
          .from('collections_item')
          .select('collection_Id')
          .eq('post_id', _currentPost.id);
      
      final savedInIds = (response as List)
          .map((item) => item['collection_Id'] as String)
          .toSet();

      if (mounted) {
        setState(() {
          _savedInCollectionIds = savedInIds;
          _isSaved = savedInIds.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  bool _isSaving = false;

  void _toggleSave() {
    _showSaveSheet(context);
  }

  void _showSaveSheet(BuildContext context) {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) {
      _showAuthRequiredDialog();
      return;
    }
    final collectionRepo = CollectionRepository(Supabase.instance.client);

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: const BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(top: 10, bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Save to Collection',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Collection>>(
                    future: collectionRepo.getUserCollections(currentUserId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CupertinoActivityIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error loading collections'));
                      }

                      final collections =
                          snapshot.data
                              ?.where((c) => c.collectionType == 'POST')
                              .toList() ??
                          [];

                      if (collections.isEmpty) {
                        return const Center(child: Text('No collections found.'));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: collections.length,
                        separatorBuilder: (_, _) => Container(
                          height: 1,
                          color: CupertinoColors.systemGrey5.withAlpha(50),
                        ),
                        itemBuilder: (context, index) {
                          final collection = collections[index];
                          final isAlreadyIn = _savedInCollectionIds.contains(collection.collectionId);

                          return CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            onPressed: _isSaving ? null : () async {
                              if (isAlreadyIn) {
                                await _unsaveFromSpecificCollection(collection.collectionId);
                              } else {
                                await _saveToSpecificCollection(collection.collectionId);
                              }
                              setSheetState(() {}); // Refresh sheet UI
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isAlreadyIn ? AppColors.primary.withAlpha(20) : AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isAlreadyIn ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.folder_fill,
                                    color: isAlreadyIn ? AppColors.primary : AppColors.textLight,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        collection.name,
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: isAlreadyIn ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                      if (collection.isDefault)
                                        const Text(
                                          'Default Collection',
                                          style: TextStyle(color: AppColors.textLight, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isAlreadyIn)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'SAVED',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unsaveFromSpecificCollection(String collectionId) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final collectionRepo = CollectionRepository(Supabase.instance.client);
      await collectionRepo.removePostFromCollection(collectionId, _currentPost.id);

      setState(() {
        _savedInCollectionIds.remove(collectionId);
        _isSaved = _savedInCollectionIds.isNotEmpty;
        _currentPost = _currentPost.copyWith(
          saveCount: (_currentPost.saveCount - 1).clamp(0, 999999),
        );
        _wasEdited = true;
      });
    } catch (e) {
      debugPrint('Unsave error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _checkLikeStatus() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (mounted) setState(() => _isLiked = false);
      return;
    }

    try {
      final isLiked = await PostRepository.instance.checkIsLiked(
        _currentPost.id,
        currentUserId,
      );
      if (mounted) setState(() => _isLiked = isLiked);
    } catch (_) {}
  }

  bool _isLiking = false;

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      _showAuthRequiredDialog();
      return;
    }
    setState(() => _isLiking = true);

    final newIsLiked = !_isLiked;
    final rawNewCount = _currentPost.likes + (newIsLiked ? 1 : -1);
    final newCount = rawNewCount < 0 ? 0 : rawNewCount;

    setState(() {
      _isLiked = newIsLiked;
      _currentPost = _currentPost.copyWith(
        likes: newCount,
        isLiked: newIsLiked,
      );
      _wasEdited = true;
    });

    try {
      await PostRepository.instance.toggleLike(
        _currentPost.id,
        currentUserId,
        newIsLiked,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _currentPost = _currentPost.copyWith(
            likes: newCount + (newIsLiked ? -1 : 1),
            isLiked: !newIsLiked,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  void _navigateToProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ProfileScreen(userId: userId),
      ),
    );
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
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _submitComment(BuildContext modalContext) async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPostingComment) return;

    final editingComment = _editingComment;
    if (editingComment != null && text == editingComment.content.trim()) {
      Navigator.pop(modalContext);
      return;
    }

    setState(() => _isPostingComment = true);
    try {
      final currentUserId = SupabaseService.requireCurrentUserId();
      if (editingComment != null) {
        final updatedComment = await CommentRepository.instance.updateComment(
          commentId: editingComment.commentId,
          userId: currentUserId,
          content: text,
        );
        if (mounted) {
          setState(() {
            final index = _comments.indexWhere(
              (comment) => comment.commentId == updatedComment.commentId,
            );
            if (index != -1) {
              _comments[index] = updatedComment;
            }
          });
          if (modalContext.mounted) {
            Navigator.pop(modalContext);
          }
        }
      } else {
        final newComment = await CommentRepository.instance.postComment(
          postId: _currentPost.id,
          userId: currentUserId,
          content: text,
        );
        if (mounted) {
          setState(() => _comments.insert(0, newComment));
          if (modalContext.mounted) {
            Navigator.pop(modalContext);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: Text(
              editingComment != null ? 'Failed to save' : 'Failed to post',
            ),
            content: Text(e.toString()),
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
    final scaffold = CupertinoPageScaffold(
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
              SliverToBoxAdapter(child: _buildHashtags()),
              SliverToBoxAdapter(child: _buildRestaurantTag()),
              SliverToBoxAdapter(child: _buildTimestamp()),
              if (_isArchivedView)
                SliverToBoxAdapter(child: _buildArchivedNotice())
              else ...[
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 6,
                    child: ColoredBox(color: Color(0xFFF0F0F0)),
                  ),
                ),
                SliverToBoxAdapter(child: _buildCommentsHeader()),
                _isLoadingComments
                    ? SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, _) => const _CommentSkeleton(),
                          childCount: 3,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildCommentTile(_comments[i]),
                          childCount: _comments.length,
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ],
          ),
          if (!_isArchivedView)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(context),
            ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_wasEdited ? _currentPost : null);
      },
      child: scaffold,
    );
  }

  Widget _buildAuthorHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () =>
                  Navigator.of(context).pop(_wasEdited ? _currentPost : null),
              child: const Icon(
                CupertinoIcons.chevron_back,
                color: AppColors.textPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _navigateToProfile(_currentPost.userId),
              child: ClipOval(
                child: Image.network(
                  _currentPost.authorAvatar,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
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
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToProfile(_currentPost.userId),
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
                  ],
                ),
              ),
            ),
            if (_currentPost.userId !=
                Supabase.instance.client.auth.currentUser?.id) ...[
              GestureDetector(
                onTap: _toggleFollow,
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
                    _isFollowUpdating
                        ? '...'
                        : (_isFollowing ? 'Following' : 'Follow'),
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
            ],
            GestureDetector(
              onTap: () => _showMoreOptions(context),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  _isCurrentUserPostOwner
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
              errorBuilder: (context, error, stackTrace) => Container(
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
        if (_images.length > 1)
          Positioned(
            bottom: 12,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(115),
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
        Positioned(
          bottom: 16,
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
                      : Colors.white.withAlpha(150),
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
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.55,
                ),
                children: _buildCaptionSpans(_currentPost.description),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<InlineSpan> _buildCaptionSpans(String text) {
    final children = <InlineSpan>[];
    var currentIndex = 0;

    for (final match in _captionHashtagPattern.allMatches(text)) {
      if (!_isCaptionHashtagBoundary(text, match.start)) {
        continue;
      }

      if (match.start > currentIndex) {
        children.add(
          TextSpan(text: text.substring(currentIndex, match.start)),
        );
      }

      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F4),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFFFD4DD),
                  width: 0.9,
                ),
              ),
              child: Text(
                match.group(0) ?? '',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      children.add(TextSpan(text: text.substring(currentIndex)));
    }

    return children;
  }

  bool _isCaptionHashtagBoundary(String text, int index) {
    if (index == 0) {
      return true;
    }
    return _captionWhitespacePattern.hasMatch(text[index - 1]);
  }

  Widget _buildHashtags() {
    final captionHashtags = HashtagUtils.extractHashtagsFromText(
      _currentPost.description,
    );
    if (_currentPost.hashtags.isEmpty || captionHashtags.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _currentPost.hashtags.map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F4),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFFFD4DD),
                width: 0.9,
              ),
            ),
            child: Text(
              HashtagUtils.format(tag),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: -0.2,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRestaurantTag() {
    if (_currentPost.restaurantName.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: GestureDetector(
        onTap: () {
          final restaurantId = _currentPost.restaurantId;
          if (restaurantId != null && restaurantId.isNotEmpty) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => RestaurantDetailScreen(
                  restaurantId: restaurantId,
                ),
              ),
            );
          } else {
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Unavailable'),
                content: const Text('Restaurant details are unavailable.'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('OK'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            );
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

  Widget _buildArchivedNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              CupertinoIcons.archivebox_fill,
              size: 18,
              color: AppColors.textLight,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This post is in Archived Posts. Use the menu above to recover it.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Text(
        _isLoadingComments
            ? 'Loading comments…'
            : '${_comments.length} Comments',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildCommentTile(CommentModel comment) {
    return GestureDetector(
      onLongPress: () => _showCommentOptions(context, comment),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _navigateToProfile(comment.userId),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(30),
                ),
                child: ClipOval(
                  child: (comment.authorAvatar != null && comment.authorAvatar!.isNotEmpty)
                      ? Image.network(
                          comment.authorAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              comment.initials,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            comment.initials,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _navigateToProfile(comment.userId),
                    child: Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
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

  Widget _buildBottomBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
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
            color: CupertinoColors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
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
                label: _formatCount(_currentPost.saveCount),
                color: _isSaved ? AppColors.primary : AppColors.textSecondary,
                onTap: _toggleSave,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCommentSheet(
    BuildContext context, {
    CommentModel? editingComment,
  }) async {
    final initialText = editingComment?.content ?? '';
    _commentController
      ..text = initialText
      ..selection = TextSelection.collapsed(offset: initialText.length);
    if (mounted) {
      setState(() => _editingComment = editingComment);
    }

    await showCupertinoModalPopup(
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: (_currentUserAvatar != null && _currentUserAvatar!.isNotEmpty)
                        ? Image.network(
                            _currentUserAvatar!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              CupertinoIcons.person_fill,
                              color: AppColors.textLight,
                              size: 20,
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.person_fill,
                            color: AppColors.textLight,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoTextField(
                    controller: _commentController,
                    autofocus: true,
                    placeholder: editingComment != null
                        ? 'Edit your comment...'
                        : 'Add a comment...',
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
                  onPressed: () => _submitComment(ctx),
                  child: Text(
                    editingComment != null ? 'Save' : 'Post',
                    style: const TextStyle(
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

    _commentController.clear();
    if (mounted) {
      setState(() => _editingComment = null);
    }
  }

  void _showMoreOptions(BuildContext context) {
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
                    if (_isArchivedView)
                      ...[
                        _buildHorizontalOption(
                          icon: CupertinoIcons.arrow_uturn_up_circle,
                          label: 'Recover',
                          onTap: () {
                            Navigator.pop(context);
                            _recoverPost();
                          },
                        ),
                        _buildHorizontalOption(
                          icon: CupertinoIcons.pencil,
                          label: 'Edit',
                          onTap: () {
                            Navigator.pop(context);
                            _editPost();
                          },
                        ),
                        _buildHorizontalOption(
                          icon: CupertinoIcons.delete,
                          label: 'Delete',
                          isDestructive: true,
                          onTap: () {
                            Navigator.pop(context);
                            _hideDeletedPostFromOwner();
                          },
                        ),
                      ]
                    else ...[
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
                      if (_isCurrentUserPostOwner)
                        ...[
                          _buildHorizontalOption(
                            icon: CupertinoIcons.pencil,
                            label: 'Edit',
                            onTap: () {
                              Navigator.pop(context);
                              _editPost();
                            },
                          ),
                          _buildHorizontalOption(
                            icon: CupertinoIcons.delete,
                            label: 'Delete',
                            isDestructive: true,
                            onTap: () {
                              Navigator.pop(context);
                              _deletePost();
                            },
                          ),
                        ]
                      else
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToSpecificCollection(String collectionId) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final collectionRepo = CollectionRepository(Supabase.instance.client);
      await collectionRepo.savePostToCollection(collectionId, _currentPost.id);

      setState(() {
        _savedInCollectionIds.add(collectionId);
        _isSaved = true;
        _currentPost = _currentPost.copyWith(
          saveCount: _currentPost.saveCount + 1,
        );
        _wasEdited = true;
      });
    } catch (e) {
      debugPrint('Save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showCommentOptions(BuildContext context, CommentModel comment) {
    final isOwner = _currentUserId != null && comment.userId == _currentUserId;

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
                      ...[
                        _buildHorizontalOption(
                          icon: CupertinoIcons.pencil,
                          label: 'Edit',
                          onTap: () {
                            Navigator.pop(modalContext);
                            _showCommentSheet(
                              context,
                              editingComment: comment,
                            );
                          },
                        ),
                        _buildHorizontalOption(
                          icon: CupertinoIcons.delete,
                          label: 'Delete',
                          isDestructive: true,
                          onTap: () {
                            Navigator.pop(modalContext);
                            _deleteComment(comment);
                          },
                        ),
                      ]
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
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Archive Post?'),
        content: const Text('This post will move to your Archived Posts tab.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await PostRepository.instance.deletePost(_currentPost.id);
      _wasEdited = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Archive Failed'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _recoverPost() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Recover Post?'),
        content: const Text(
          'This post will return to your normal posts and leave Archived Posts.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recover'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await PostRepository.instance.restorePost(_currentPost.id);
      _wasEdited = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Recover Failed'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _editPost() async {
    final result = await Navigator.of(context).push<PostModel>(
      CupertinoPageRoute(
        builder: (_) => EditPostScreen(post: _currentPost),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _currentPost = result;
      _wasEdited = true;
    });
  }

  Future<void> _hideDeletedPostFromOwner() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text(
          'This will remove the post from your Archived Posts. Admins can still access it if needed.',
        ),
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
      await PostRepository.instance.hideDeletedPostFromOwner(_currentPost.id);
      _wasEdited = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Delete Failed'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

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

class _CommentSkeleton extends StatelessWidget {
  const _CommentSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonCircle(size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(width: 80, height: 12),
                const SizedBox(height: 6),
                const Skeleton(width: double.infinity, height: 14),
                const SizedBox(height: 4),
                const Skeleton(width: 150, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
