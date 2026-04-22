import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late PostModel _currentPost;
  bool _isLiked = false;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _checkLikeStatus();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      setState(() {
        _currentPost = widget.post;
        _isLiked = false; // Reset visually until DB check finishes
      });
      _checkLikeStatus();
    } else if (oldWidget.post != widget.post) {
      // If the post is the same ID but updated (like count changed externally)
      setState(() {
        _currentPost = widget.post;
      });
    }
  }

  Future<void> _checkLikeStatus() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        if (mounted) setState(() => _isLiked = false);
        return;
      }

      final isLiked = await PostRepository.instance.checkIsLiked(
        _currentPost.id,
        currentUserId,
      );
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _isLiking = true);

    final newIsLiked = !_isLiked;
    // ensure likes never drop below 0 just as a pure safety guard
    final rawNewCount = _currentPost.likes + (newIsLiked ? 1 : -1);
    final newCount = rawNewCount < 0 ? 0 : rawNewCount;

    setState(() {
      _isLiked = newIsLiked;
      _currentPost = _currentPost.copyWith(likes: newCount);
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
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              child: AspectRatio(
                // PostModel.aspectRatio is h/w (>1 = tall); AspectRatio needs w/h
                aspectRatio: 1 / _currentPost.aspectRatio,
                child: Image.network(
                  _currentPost.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surface,
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.photo,
                        color: AppColors.textLight,
                        size: 28,
                      ),
                    ),
                  ),
                  loadingBuilder: (_, child, progress) {
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
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Text(
                _currentPost.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── User row + like ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  // Avatar
                  ClipOval(
                    child: Image.network(
                      _currentPost.authorAvatar,
                      width: 16,
                      height: 16,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 16,
                        height: 16,
                        color: AppColors.surface,
                        child: const Icon(
                          CupertinoIcons.person_fill,
                          size: 10,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Username
                  Expanded(
                    child: Text(
                      _currentPost.authorName,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textPrimary,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  // Like button
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        Icon(
                          _isLiked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          size: 14,
                          color: _isLiked
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatCount(_currentPost.likes),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
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
