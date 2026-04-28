import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/collection_model.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';
import 'package:taste_spot/features/post/screens/post_detail_screen.dart';
import 'package:taste_spot/features/restaurant/screens/restaurant_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/data/repositories/collection_repository.dart';
import 'package:taste_spot/data/models/profile_model.dart';
import 'package:taste_spot/data/repositories/profile_repository.dart';
import 'package:taste_spot/core/widgets/post_card.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/repositories/repository_support.dart';

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
  List<RestaurantModel> _restaurants = [];
  bool _isLoading = true;
  bool _isCloning = false;
  String? _error;
  bool _isRestaurantSelectionMode = false;
  final Set<String> _selectedRestaurantIds = {};
  bool _isRemovingRestaurants = false;

  late final CollectionRepository _collectionRepository;

  bool get _isOwner {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return currentUser != null && currentUser.id == widget.collection.userId;
  }

  bool get _isRestaurantCollection {
    return widget.collection.collectionType == 'RESTAURANT';
  }

  bool get _canSelectRestaurants {
    return _isRestaurantCollection && _isOwner;
  }

  @override
  void initState() {
    super.initState();
    _collectionRepository = CollectionRepository(Supabase.instance.client);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    if (widget.collection.collectionType == 'RESTAURANT') {
      _loadRestaurants();
    } else {
      _loadPosts();
    }
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

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final postsResponse = await Supabase.instance.client
          .from('Post')
          .select(getPostSelectWithStatus(currentUserId))
          .inFilter('post_Id', postIds)
          .eq('isRemoved', false)
          .eq('isBlocked', false);

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
    return _posts
        .where(
          (p) =>
              p.title.toLowerCase().contains(lowerQuery) ||
              p.restaurantName.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final restaurants = await _collectionRepository
          .getRestaurantsInCollection(widget.collection.collectionId);

      if (mounted) {
        setState(() {
          _restaurants = restaurants;
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

  List<RestaurantModel> get _filteredRestaurants {
    if (_searchQuery.isEmpty) return _restaurants;
    final lowerQuery = _searchQuery.toLowerCase();
    return _restaurants
        .where(
          (r) =>
              r.name.toLowerCase().contains(lowerQuery) ||
              (r.mainCuisineId?.toLowerCase().contains(lowerQuery) ?? false) ||
              (r.address?.toLowerCase().contains(lowerQuery) ?? false),
        )
        .toList();
  }

  bool get _isAllFilteredSelected {
    final visible = _filteredRestaurants;
    if (visible.isEmpty) return false;
    return visible.every(
      (r) => _selectedRestaurantIds.contains(r.restaurantId),
    );
  }

  Future<void> _refreshCollection() async {
    if (widget.collection.collectionType == 'RESTAURANT') {
      await _loadRestaurants();
    } else {
      await _loadPosts();
    }
  }

  void _enterRestaurantSelectionMode(String restaurantId) {
    if (!_canSelectRestaurants) return;
    setState(() {
      _isRestaurantSelectionMode = true;
      _selectedRestaurantIds.add(restaurantId);
    });
  }

  void _toggleRestaurantSelection(String restaurantId) {
    if (!_canSelectRestaurants) return;
    setState(() {
      if (_selectedRestaurantIds.contains(restaurantId)) {
        _selectedRestaurantIds.remove(restaurantId);
      } else {
        _selectedRestaurantIds.add(restaurantId);
      }

      if (_selectedRestaurantIds.isEmpty) {
        _isRestaurantSelectionMode = false;
      }
    });
  }

  void _exitRestaurantSelectionMode() {
    setState(() {
      _isRestaurantSelectionMode = false;
      _selectedRestaurantIds.clear();
    });
  }

  void _toggleSelectAllRestaurants() {
    if (!_canSelectRestaurants) return;
    final visible = _filteredRestaurants;
    if (visible.isEmpty) return;

    if (_isAllFilteredSelected) {
      _exitRestaurantSelectionMode();
      return;
    }

    setState(() {
      _isRestaurantSelectionMode = true;
      _selectedRestaurantIds
        ..clear()
        ..addAll(visible.map((r) => r.restaurantId));
    });
  }

  void _showRemoveSelectedRestaurantsDialog() {
    if (_selectedRestaurantIds.isEmpty) return;
    final count = _selectedRestaurantIds.length;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Remove from collection?'),
        content: Text(
          'This will remove $count restaurant(s) from this collection.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeSelectedRestaurants();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSelectedRestaurants() async {
    if (_selectedRestaurantIds.isEmpty) return;
    if (_isRemovingRestaurants) return;

    final ids = _selectedRestaurantIds.toList();
    setState(() {
      _isRemovingRestaurants = true;
    });

    try {
      await _collectionRepository.removeRestaurantsFromCollection(
        widget.collection.collectionId,
        ids,
      );

      if (!mounted) return;
      setState(() {
        _restaurants = _restaurants
            .where((r) => !_selectedRestaurantIds.contains(r.restaurantId))
            .toList();
        _isRestaurantSelectionMode = false;
        _selectedRestaurantIds.clear();
        _isRemovingRestaurants = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isRemovingRestaurants = false;
      });
    }
  }

  Future<void> _cloneCollection() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isCloning = true);

    try {
      await _collectionRepository.cloneCollection(
        userId: currentUser.id,
        sourceCollection: widget.collection,
      );

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: const Text(
              'Collection cloned successfully to your library.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to clone collection: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCloning = false);
    }
  }

  void _confirmDelete() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Collection'),
        content: const Text(
          'Are you sure you want to delete this collection? This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _collectionRepository.deleteCollection(
                  widget.collection.collectionId,
                );
                if (mounted) {
                  Navigator.pop(context, true);
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
        return _ShareSheet(collectionId: widget.collection.collectionId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRestaurantSelectionActive =
        _canSelectRestaurants && _isRestaurantSelectionMode;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: CupertinoColors.white,
        border: null,
        leading: isRestaurantSelectionActive
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _exitRestaurantSelectionMode,
                child: const Text('Cancel'),
              )
            : null,
        middle: isRestaurantSelectionActive
            ? Text('${_selectedRestaurantIds.length} selected')
            : Text(
                widget.collection.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
        trailing: isRestaurantSelectionActive
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _toggleSelectAllRestaurants,
                    child: Text(
                      _isAllFilteredSelected ? 'Unselect All' : 'Select All',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed:
                        _selectedRestaurantIds.isEmpty || _isRemovingRestaurants
                        ? null
                        : _showRemoveSelectedRestaurantsDialog,
                    child: _isRemovingRestaurants
                        ? const CupertinoActivityIndicator(radius: 10)
                        : const Icon(
                            CupertinoIcons.trash,
                            color: AppColors.primary,
                            size: 20,
                          ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isOwner) ...[
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showShareSheet,
                      child: const Icon(
                        CupertinoIcons.person_add,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ),
                    if (!widget.collection.isDefault) ...[
                      const SizedBox(width: 12),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _confirmDelete,
                        child: const Icon(
                          CupertinoIcons.trash,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ] else if (widget.collection.isCloneable) ...[
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isCloning ? null : _cloneCollection,
                      child: _isCloning
                          ? const CupertinoActivityIndicator()
                          : const Icon(
                              CupertinoIcons.plus_square_on_square,
                              color: AppColors.primary,
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
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.search,
                      size: 18,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CupertinoTextField(
                        controller: _searchController,
                        placeholder: 'Search in collection...',
                        placeholderStyle: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                        decoration: null,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final isRestaurant = widget.collection.collectionType == 'RESTAURANT';

    if (_isLoading) {
      if (isRestaurant) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _refreshCollection),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.divider,
                          width: 0.6,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Skeleton(width: 56, height: 56, borderRadius: 8),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Skeleton(width: 120, height: 14),
                                SizedBox(height: 6),
                                Skeleton(width: 180, height: 12),
                                SizedBox(height: 8),
                                Skeleton(
                                  width: 60,
                                  height: 18,
                                  borderRadius: 99,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  childCount: 8,
                ),
              ),
            ),
          ],
        );
      }

      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _refreshCollection),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Skeleton(borderRadius: 12)),
                    SizedBox(height: 8),
                    Skeleton(width: 100, height: 14),
                  ],
                ),
                childCount: 6,
              ),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _refreshCollection),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRestaurant
                        ? 'Failed to load restaurants'
                        : 'Failed to load posts',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    onPressed: isRestaurant ? _loadRestaurants : _loadPosts,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (isRestaurant) {
      final restaurantsToShow = _filteredRestaurants;

      if (restaurantsToShow.isEmpty) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _refreshCollection),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.building_2_fill,
                      size: 48,
                      color: AppColors.surface,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _restaurants.isEmpty
                          ? 'No saved restaurants yet'
                          : 'No matches found',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _refreshCollection),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final r = restaurantsToShow[index];
                final coverUrl = r.imageUrls.isNotEmpty
                    ? r.imageUrls.first
                    : null;

                final isSelectionActive =
                    _canSelectRestaurants && _isRestaurantSelectionMode;
                final isSelected = _selectedRestaurantIds.contains(
                  r.restaurantId,
                );
                final backgroundColor = isSelectionActive && isSelected
                    ? AppColors.primary.withAlpha(16)
                    : CupertinoColors.white;
                final borderColor = isSelectionActive && isSelected
                    ? AppColors.primary.withAlpha(80)
                    : AppColors.divider;
                final trailingIcon = isSelectionActive
                    ? (isSelected
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.circle)
                    : CupertinoIcons.chevron_right;
                final trailingColor = isSelectionActive
                    ? (isSelected ? AppColors.primary : AppColors.textSecondary)
                    : AppColors.textLight;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      if (isSelectionActive) {
                        _toggleRestaurantSelection(r.restaurantId);
                        return;
                      }
                      final result = await Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => RestaurantDetailScreen(
                            restaurantId: r.restaurantId,
                          ),
                        ),
                      );
                      if (result == true && mounted) _loadRestaurants();
                    },
                    onLongPress: () {
                      if (!_canSelectRestaurants) return;
                      if (isSelectionActive) {
                        _toggleRestaurantSelection(r.restaurantId);
                      } else {
                        _enterRestaurantSelectionMode(r.restaurantId);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 0.6),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: coverUrl != null
                                ? Image.network(
                                    coverUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 56,
                                      height: 56,
                                      color: AppColors.surface,
                                      child: const Icon(
                                        CupertinoIcons.photo,
                                        size: 18,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 56,
                                    height: 56,
                                    color: AppColors.surface,
                                    child: const Icon(
                                      CupertinoIcons.photo,
                                      size: 18,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  r.address ?? '-',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    r.mainCuisineId ?? '-',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(trailingIcon, size: 16, color: trailingColor),
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: restaurantsToShow.length),
            ),
          ),
        ],
      );
    }

    final postsToShow = _filteredPosts;

    if (postsToShow.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _refreshCollection),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.square_favorites,
                    size: 48,
                    color: AppColors.surface,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _posts.isEmpty
                        ? 'This collection is empty'
                        : 'No matches found',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final leftCol = <PostModel>[];
    final rightCol = <PostModel>[];
    for (int i = 0; i < postsToShow.length; i++) {
      (i.isEven ? leftCol : rightCol).add(postsToShow[i]);
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _refreshCollection),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: leftCol
                        .map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PostCard(
                              post: post,
                              onTap: () async {
                                final result = await Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (_) =>
                                        PostDetailScreen(post: post),
                                  ),
                                );
                                if (result == true && mounted) _loadPosts();
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: rightCol
                        .map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PostCard(
                              post: post,
                              onTap: () async {
                                final result = await Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (_) =>
                                        PostDetailScreen(post: post),
                                  ),
                                );
                                if (result == true && mounted) _loadPosts();
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      final sharedIdsList = await collectionRepo.getSharedUserIds(
        widget.collectionId,
      );

      if (mounted) {
        setState(() {
          _followers = followers;
          _sharedUserIds = sharedIdsList.toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleShare(Profile follower) async {
    final collectionRepo = CollectionRepository(Supabase.instance.client);
    final isShared = _sharedUserIds.contains(follower.userId);

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
        await collectionRepo.shareCollection(
          widget.collectionId,
          follower.userId,
        );
      }
    } catch (e) {
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
        color: CupertinoColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Share Collection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppColors.textLight,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _followers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.person_2,
                            size: 48,
                            color: AppColors.surface,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No followers to share with',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _followers.length,
                      itemBuilder: (context, index) {
                        final follower = _followers[index];
                        final isShared = _sharedUserIds.contains(
                          follower.userId,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: CupertinoColors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child:
                                      (follower.imageUrl != null &&
                                          follower.imageUrl!.isNotEmpty)
                                      ? Image.network(
                                          follower.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    CupertinoIcons.person_fill,
                                                    color: AppColors.textLight,
                                                    size: 24,
                                                  ),
                                        )
                                      : const Icon(
                                          CupertinoIcons.person_fill,
                                          color: AppColors.textLight,
                                          size: 24,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  follower.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              CupertinoSwitch(
                                value: isShared,
                                activeTrackColor: AppColors.primary,
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
