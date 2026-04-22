import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/collection_model.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/features/post/screens/post_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollectionDetailScreen extends StatefulWidget {
  final Collection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<PostModel> _posts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final itemsResponse = await Supabase.instance.client
          .from('collections_item')
          .select('post_id')
          .eq('collection_Id', widget.collection.collectionId);

      final postIds = (itemsResponse as List<dynamic>)
          .map((row) => row['post_id'] as String?)
          .whereType<String>()
          .toList();

      if (postIds.isEmpty) {
        if (mounted) {
          setState(() {
            _posts = [];
            _isLoading = false;
          });
        }
        return;
      }

      final postsResponse = await Supabase.instance.client
          .from('Post')
          .select('''
            post_Id,
            caption,
            likeCount,
            saveCount,
            created_At,
            User!Post_user_Id_fkey(user_Id, name),
            Restaurant(restaurant_Id, restaurant_name)
          ''')
          .inFilter('post_Id', postIds);

      final posts = (postsResponse as List<dynamic>)
          .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<PostModel> get _filteredPosts {
    if (_searchQuery.isEmpty) return _posts;
    final lowerQuery = _searchQuery.toLowerCase();
    return _posts.where((p) =>
        p.title.toLowerCase().contains(lowerQuery) ||
        p.restaurantName.toLowerCase().contains(lowerQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: AppColors.background,
        border: null,
        middle: Text(
          widget.collection.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        previousPageTitle: 'Back',
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search posts in this collection...',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: _buildGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Failed to load posts',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadPosts,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final postsToShow = _filteredPosts;

    if (postsToShow.isEmpty) {
      return Center(
        child: Text(
          _posts.isEmpty ? 'No posts yet' : 'No matches found',
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: postsToShow.length,
      itemBuilder: (context, index) {
        final post = postsToShow[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => PostDetailScreen(post: post)),
            );
          },
          child: _XhsCard(post: post),
        );
      },
    );
  }
}

// XHS CARD — image + title + like count
class _XhsCard extends StatelessWidget {
  final PostModel post;
  const _XhsCard({required this.post});

  String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: post.imageUrl.isNotEmpty
                ? Image.network(
                    post.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.heart_fill,
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _fmt(post.likes),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(
          CupertinoIcons.photo,
          color: AppColors.textLight,
          size: 28,
        ),
      ),
    );
  }
}
