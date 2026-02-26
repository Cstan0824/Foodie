import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../theme/app_theme.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: AspectRatio(
                // PostModel.aspectRatio is h/w (>1 = tall); AspectRatio needs w/h
                aspectRatio: 1 / widget.post.aspectRatio,
                child: Image.network(
                  widget.post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surface,
                    child: const Center(
                      child: Icon(CupertinoIcons.photo,
                          color: AppColors.textLight, size: 28),
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
                widget.post.title,
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
                      widget.post.authorAvatar,
                      width: 16,
                      height: 16,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 16,
                        height: 16,
                        color: AppColors.surface,
                        child: const Icon(CupertinoIcons.person_fill,
                            size: 10, color: AppColors.textLight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Username
                  Expanded(
                    child: Text(
                      widget.post.authorName,
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
                    onTap: () => setState(() => _isLiked = !_isLiked),
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
                          _formatCount(
                              widget.post.likes + (_isLiked ? 1 : 0)),
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
