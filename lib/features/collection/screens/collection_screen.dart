import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors; // For slight shadows
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/collection_model.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/repositories/collection_repository.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  // Simulating tabs for "Saved Posts" and "My Albums"
  int _selectedSegment = 0;

  final CollectionRepository _collectionRepository = CollectionRepository(
    Supabase.instance.client,
  );
  List<Collection> _collections = [];
  bool _isLoadingCollections = true;
  String? _collectionError;

  List<PostModel> _savedPosts = [];
  bool _isLoadingSavedPosts = true;
  String? _savedPostsError;

  @override
  void initState() {
    super.initState();
    _loadCollections();
    _loadSavedPosts();
  }

  Future<void> _loadCollections() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _collections = [];
          _isLoadingCollections = false;
          _collectionError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingCollections = true;
        _collectionError = null;
      });
    }

    try {
      final collections = await _collectionRepository.getUserCollections(
        user.id,
      );
      if (mounted) {
        setState(() {
          _collections = collections;
          _isLoadingCollections = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCollections = false;
          _collectionError = e.toString();
        });
      }
    }
  }

  Future<void> _loadSavedPosts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _savedPosts = [];
          _isLoadingSavedPosts = false;
          _savedPostsError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingSavedPosts = true;
        _savedPostsError = null;
      });
    }

    try {
      final savedPostIds = await _collectionRepository.getSavedPostIdsForUser(
        user.id,
      );

      if (savedPostIds.isEmpty) {
        if (mounted) {
          setState(() {
            _savedPosts = [];
            _isLoadingSavedPosts = false;
          });
        }
        return;
      }

      final posts = await PostRepository.instance.fetchPostsByIds(savedPostIds);
      if (mounted) {
        setState(() {
          _savedPosts = posts;
          _isLoadingSavedPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _savedPosts = [];
          _isLoadingSavedPosts = false;
          _savedPostsError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: CupertinoColors.white,
        border: null, // Clean look
        middle: const Text(
          'Collections',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {},
          child: const Icon(
            CupertinoIcons.add,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Segmented Control (Tabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  backgroundColor: AppColors.surface,
                  thumbColor: AppColors.primary,
                  groupValue: _selectedSegment,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Albums',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _selectedSegment == 0
                              ? CupertinoColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'All Saved',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _selectedSegment == 1
                              ? CupertinoColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) setState(() => _selectedSegment = value);
                  },
                ),
              ),
            ),

            // Content
            Expanded(
              child: _selectedSegment == 0
                  ? _buildAlbumsGrid()
                  : _buildAllSavedGrid(),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // TAB 1: ALL SAVED POSTS (Masonry Grid Style)
  // ══════════════════════════════════════════
  Widget _buildAllSavedGrid() {
    if (_isLoadingSavedPosts) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_savedPostsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Failed to load saved posts',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadSavedPosts,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_savedPosts.isEmpty) {
      return const Center(
        child: Text(
          'No saved posts yet',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 0.8, // Slightly taller for "card" feel or square
      ),
      itemCount: _savedPosts.length,
      itemBuilder: (context, index) {
        final post = _savedPosts[index];
        return GestureDetector(
          onTap: () {},
          child: post.imageUrl.isNotEmpty
              ? Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : Container(
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.photo,
                        color: AppColors.textLight,
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.title.isEmpty ? 'Saved post' : post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  // TAB 2: ALBUMS GRID
  // ══════════════════════════════════════════
  Widget _buildAlbumsGrid() {
    if (_isLoadingCollections) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_collectionError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Failed to load collections',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadCollections,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_collections.isEmpty) {
      return const Center(
        child: Text(
          'No collections yet',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _collections.length,
      itemBuilder: (context, index) {
        final album = _collections[index];
        return GestureDetector(
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Cover
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.surface, CupertinoColors.white],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          CupertinoIcons.collections,
                          size: 34,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (!album.isPublic)
                        Container(
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.lock_fill,
                              size: 12,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              // Count
              Text(
                album.isPublic ? 'Public collection' : 'Private collection',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
