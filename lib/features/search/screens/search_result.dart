import 'package:flutter/cupertino.dart';
import 'package:taste_spot/data/repositories/search_repository.dart';
import 'package:taste_spot/core/widgets/post_card.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';
import 'package:taste_spot/features/post/screens/post_detail_screen.dart';
import 'package:taste_spot/features/restaurant/screens/restaurant_detail_screen.dart';

class SearchResultScreen extends StatefulWidget {
  final String initialQuery;

  const SearchResultScreen({super.key, required this.initialQuery});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  late final String _query;
  SearchResultFilter _filter = SearchResultFilter.all;
  SearchSortMode _sort = SearchSortMode.top;

  bool _isLoading = true;
  String? _error;
  List<RestaurantSearchResult> _restaurants = const [];
  List<PostSearchResult> _posts = const [];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _loadResults();
  }

  SearchScope get _scope {
    switch (_filter) {
      case SearchResultFilter.restaurants:
        return SearchScope.restaurants;
      case SearchResultFilter.posts:
        return SearchScope.posts;
      case SearchResultFilter.all:
        return SearchScope.all;
    }
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final payload = await SearchRepository.instance.search(
        query: _query,
        scope: _scope,
        sortMode: _sort,
        restaurantPreviewLimit: 3,
        restaurantLimit: 30,
        postLimit: 60,
      );
      if (!mounted) return;
      setState(() {
        _restaurants = payload.restaurants;
        _posts = payload.posts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _changeFilter(SearchResultFilter value) {
    if (_filter == value) return;
    if (mounted) {
      setState(() {
        _filter = value;
      });
    }
    _loadResults();
  }

  void _changeSort(SearchSortMode value) {
    if (_sort == value) return;
    if (mounted) {
      setState(() {
        _sort = value;
      });
    }
    _loadResults();
  }

  double _tabUnderlineWidth(String label) {
    switch (label) {
      case 'All':
        return 15;
      case 'Posts':
        return 25;
      case 'Restaurants':
        return 50;
      case 'Top':
        return 15;
      case 'Latest':
        return 28;
      case 'Nearby':
        return 32;
      default:
        return 25;
    }
  }

  String get _normalizedQuery => _query.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildResultBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 34,
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(
                  CupertinoIcons.back,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _query,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildControlTabs(),
        ],
      ),
    );
  }

  Widget _buildControlTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(width: 10),
            _buildTextUnderlineControl(
              label: 'All',
              selected: _filter == SearchResultFilter.all,
              onTap: () => _changeFilter(SearchResultFilter.all),
            ),
          ],
        ),
        _buildTextUnderlineControl(
          label: 'Posts',
          selected: _filter == SearchResultFilter.posts,
          onTap: () => _changeFilter(SearchResultFilter.posts),
        ),
        _buildTextUnderlineControl(
          label: 'Restaurants',
          selected: _filter == SearchResultFilter.restaurants,
          onTap: () => _changeFilter(SearchResultFilter.restaurants),
        ),
        _buildTextUnderlineControl(
          label: 'Top',
          selected: _sort == SearchSortMode.top,
          onTap: () => _changeSort(SearchSortMode.top),
        ),
        _buildTextUnderlineControl(
          label: 'Latest',
          selected: _sort == SearchSortMode.latest,
          onTap: () => _changeSort(SearchSortMode.latest),
        ),
        Row(
          children: [
            _buildTextUnderlineControl(
              label: 'Nearby',
              selected: _sort == SearchSortMode.nearby,
              onTap: () => _changeSort(SearchSortMode.nearby),
            ),
            SizedBox(width: 10),
          ],
        ),
      ],
    );
  }

  Widget _buildTextUnderlineControl({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: selected ? 16 : 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: selected ? _tabUnderlineWidth(label) : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBody() {
    if (_normalizedQuery.isEmpty) {
      return const _SearchEmptyState(
        icon: CupertinoIcons.search,
        message: 'Type something to search',
      );
    }

    if (_isLoading) {
      return _SearchSkeleton(filter: _filter);
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.wifi_exclamationmark,
                size: 40,
                color: AppColors.textLight,
              ),
              const SizedBox(height: 12),
              const Text(
                'Failed to load search results',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: _loadResults,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final restaurants = _restaurants;
    final posts = _posts;

    if (_filter == SearchResultFilter.all &&
        restaurants.isEmpty &&
        posts.isEmpty) {
      return _SearchEmptyState(
        icon: CupertinoIcons.search,
        message: 'No results found for "$_query"',
      );
    }

    if (_filter == SearchResultFilter.restaurants && restaurants.isEmpty) {
      return _SearchEmptyState(
        icon: CupertinoIcons.building_2_fill,
        message: 'No restaurant matches for "$_query"',
      );
    }

    if (_filter == SearchResultFilter.posts && posts.isEmpty) {
      return _SearchEmptyState(
        icon: CupertinoIcons.doc_text_search,
        message: 'No post matches for "$_query"',
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          refreshTriggerPullDistance: 120.0,
          refreshIndicatorExtent: 60.0,
          onRefresh: _loadResults,
        ),
        if (_filter == SearchResultFilter.restaurants)
          _buildRestaurantSliver(restaurants)
        else if (_filter == SearchResultFilter.posts)
          SliverToBoxAdapter(child: _buildPostMasonryGrid(posts))
        else ...[
          if (restaurants.isNotEmpty)
            SliverToBoxAdapter(child: _buildRestaurantPreview(restaurants)),
          SliverToBoxAdapter(child: _buildPostMasonryGrid(posts)),
        ],
      ],
    );
  }

  Widget _buildRestaurantPreview(List<RestaurantSearchResult> restaurants) {
    final preview = restaurants.take(3).toList();
    return Container(
      color: CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Restaurants',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...preview.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildRestaurantRow(r.restaurant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantSliver(List<RestaurantSearchResult> restaurants) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((_, i) {
          final row = _buildRestaurantRow(restaurants[i].restaurant);
          if (i == 0) return row;
          return Padding(padding: const EdgeInsets.only(top: 8), child: row);
        }, childCount: restaurants.length),
      ),
    );
  }

  Widget _buildRestaurantRow(RestaurantModel restaurant) {
    final coverUrl = restaurant.imageUrls.isNotEmpty
        ? restaurant.imageUrls.first
        : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => RestaurantDetailScreen(
              restaurantId: restaurant.restaurantId,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.6),
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
                    restaurant.name,
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
                    restaurant.address ?? '-',
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      restaurant.mainCuisineId ??
                          '-',
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
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostMasonryGrid(List<PostSearchResult> posts) {
    if (posts.isEmpty) {
      return const SizedBox.shrink();
    }

    final leftCol = <PostSearchResult>[];
    final rightCol = <PostSearchResult>[];
    for (int i = 0; i < posts.length; i++) {
      (i.isEven ? leftCol : rightCol).add(posts[i]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: leftCol
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PostCard(
                        post: p.post,
                        onTap: () => _openPostDetail(p.post),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: rightCol
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PostCard(
                        post: p.post,
                        onTap: () => _openPostDetail(p.post),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPostDetail(PostModel post) async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
    if (changed == true && mounted) {
      _loadResults();
    }
  }
}

enum SearchResultFilter { all, restaurants, posts }

class _SearchEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SearchEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  final SearchResultFilter filter;
  const _SearchSkeleton({required this.filter});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          if (filter == SearchResultFilter.all)
            const _RestaurantListSkeleton(itemCount: 3)
          else if (filter == SearchResultFilter.restaurants)
            const _RestaurantListSkeleton(itemCount: 9),
          if (filter == SearchResultFilter.all)
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: _MasonryGridSkeleton(itemCount: 4),
            )
          else if (filter == SearchResultFilter.posts)
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: _MasonryGridSkeleton(itemCount: 6),
            ),
        ],
      ),
    );
  }
}

class _RestaurantListSkeleton extends StatelessWidget {
  final int itemCount;
  const _RestaurantListSkeleton({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        children: List.generate(
          itemCount,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider, width: 0.6),
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
                        Skeleton(width: 60, height: 18, borderRadius: 99),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MasonryGridSkeleton extends StatelessWidget {
  final int itemCount;
  const _MasonryGridSkeleton({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: List.generate(
              itemCount ~/ 2,
              (i) => _buildCardSkeleton(i.isEven ? 240 : 180),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: List.generate(
              itemCount ~/ 2,
              (i) => _buildCardSkeleton(i.isEven ? 180 : 240),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardSkeleton(double height) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: height, borderRadius: 12),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      SkeletonCircle(size: 20),
                      SizedBox(width: 6),
                      Skeleton(width: 60, height: 10),
                    ],
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
