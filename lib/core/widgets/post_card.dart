import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final bool showAuthor;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.showAuthor = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late PostModel _currentPost;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      setState(() {
        _currentPost = widget.post;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return;
    }
    setState(() => _isLiking = true);

    final newIsLiked = !_currentPost.isLiked;
    // ensure likes never drop below 0 just as a pure safety guard
    final rawNewCount = _currentPost.likes + (newIsLiked ? 1 : -1);
    final newCount = rawNewCount < 0 ? 0 : rawNewCount;

    setState(() {
      _currentPost = _currentPost.copyWith(
        likes: newCount,
        isLiked: newIsLiked,
      );
    });

    try {
      await PostRepository.instance.toggleLike(
        _currentPost.id,
        currentUserId,
        newIsLiked,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
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

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: AspectRatio(
                aspectRatio: 1 / _currentPost.aspectRatio,
                child: Image.network(
                  _currentPost.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.surface,
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.photo,
                        color: AppColors.textLight,
                        size: 28,
                      ),
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppColors.surface,
                      child: const Center(child: CupertinoActivityIndicator()),
                    );
                  },
                ),
              ),
            ),

            // ── Caption ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Text(
                _currentPost.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── User row + Like button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  if (widget.showAuthor) ...[
                    ClipOval(
                      child: Image.network(
                        _currentPost.authorAvatar,
                        width: 18,
                        height: 18,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 18,
                          height: 18,
                          color: AppColors.surface,
                          child: const Icon(
                            CupertinoIcons.person_fill,
                            size: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _currentPost.authorName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  
                  // Like button
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentPost.isLiked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          size: 14,
                          color: _currentPost.isLiked
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(_currentPost.likes),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _currentPost.isLiked ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
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

