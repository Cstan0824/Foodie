import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/collection_model.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/features/post/screens/post_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/data/repositories/collection_repository.dart';
import 'package:taste_spot/data/models/profile_model.dart';
import 'package:taste_spot/data/repositories/profile_repository.dart';

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

  late final CollectionRepository _collectionRepository;

  @override
  void initState() {
    super.initState();
    _collectionRepository = CollectionRepository(Supabase.instance.client);
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

  void _confirmDelete() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Collection'),
        content: const Text('Are you sure you want to delete this collection? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              try {
                await _collectionRepository.deleteCollection(widget.collection.collectionId);
                if (mounted) {
                  Navigator.pop(context, true); // Pop screen and return true to refresh
                }
              } catch (e) {
                if (mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (errCtx) => CupertinoAlertDialog(
                      title: const Text('Error'),
                      content: Text('Could not delete collection: $e'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop(errCtx),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showShareSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext sheetContext) {
        return _ShareSheet(
          collectionId: widget.collection.collectionId,
        );
      },
    );
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showShareSheet,
              child: const Icon(
                CupertinoIcons.person_add,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            if (!widget.collection.isDefault) ...[
              const SizedBox(width: 16),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _confirmDelete,
                child: const Icon(
                  CupertinoIcons.trash,
                  color: CupertinoColors.destructiveRed,
                  size: 22,
                ),
              ),
            ],
          ],
        ),
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

class _ShareSheet extends StatefulWidget {
  final String collectionId;

  const _ShareSheet({required this.collectionId});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _isLoading = true;
  List<Profile> _followers = [];
  Set<String> _sharedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final profileRepo = ProfileRepository(Supabase.instance.client);
      final collectionRepo = CollectionRepository(Supabase.instance.client);

      final followers = await profileRepo.getFollowers(currentUser.id);
      final sharedIdsList = await collectionRepo.getSharedUserIds(widget.collectionId);

      if (mounted) {
        setState(() {
          _followers = followers;
          _sharedUserIds = sharedIdsList.toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading share sheet data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleShare(Profile follower) async {
    final collectionRepo = CollectionRepository(Supabase.instance.client);
    final isShared = _sharedUserIds.contains(follower.userId);

    // Optimistic UI update
    setState(() {
      if (isShared) {
        _sharedUserIds.remove(follower.userId);
      } else {
        _sharedUserIds.add(follower.userId);
      }
    });

    try {
      if (isShared) {
        await collectionRepo.removeShare(widget.collectionId, follower.userId);
      } else {
        await collectionRepo.shareCollection(widget.collectionId, follower.userId);
      }
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          if (isShared) {
            _sharedUserIds.add(follower.userId);
          } else {
            _sharedUserIds.remove(follower.userId);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Share Collection',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.textLight, size: 24),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading 
                ? const Center(child: CupertinoActivityIndicator())
                : _followers.isEmpty
                  ? const Center(
                      child: Text(
                        'You don\'t have any followers yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _followers.length,
                      itemBuilder: (context, index) {
                        final follower = _followers[index];
                        final isShared = _sharedUserIds.contains(follower.userId);
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: AppColors.divider,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    'https://i.pravatar.cc/200?u=${follower.userId}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      CupertinoIcons.person_solid, 
                                      color: AppColors.textLight, 
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  follower.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              CupertinoSwitch(
                                value: isShared,
                                activeColor: AppColors.primary,
                                onChanged: (val) => _toggleShare(follower),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

