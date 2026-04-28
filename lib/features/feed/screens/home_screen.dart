import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/post_card.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/data/repositories/feed_repository.dart';
import 'package:taste_spot/features/notification/screens/notification_screen.dart';
import 'package:taste_spot/features/post/screens/post_detail_screen.dart';
import 'package:taste_spot/features/search/screens/explore_screen.dart';
import 'package:taste_spot/data/repositories/notification_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _topNavIndex = 1; // default: Discover
  final _scrollController = ScrollController();

  static const _topNavItems = ['Following', 'Discover'];
  static const _pageSize = 20;
  static const _paginationThreshold = 300.0;

  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  int _unreadNotifCount = 0;
  double? _userLatitude;
  double? _userLongitude;

  late final NotificationRepository _notifRepo = NotificationRepository(
    SupabaseService.client,
  );

  @override
  void initState() {
    super.initState();
    loadPosts();
    _fetchUnreadCount();
    _loadUserLocation();
  }

  Future<void> _fetchUnreadCount() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final count = await _notifRepo.getUnreadCount(userId);
      if (mounted) setState(() => _unreadNotifCount = count);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore(ScrollMetrics metrics) {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    if (metrics.extentAfter <= _paginationThreshold) {
      _loadMorePosts();
    }
  }

  void _scheduleViewportFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _maybeLoadMore(_scrollController.position);
    });
  }

  bool get _isFollowingTab => _topNavIndex == 0;

  Future<List<PostModel>> _fetchFeedPage({required int offset}) {
    if (_isFollowingTab) {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        return Future.value(const []);
      }
      return PostRepository.instance.fetchFollowingPosts(
        userId: currentUserId,
        limit: _pageSize,
        offset: offset,
      );
    }

    return FeedRepository.instance.fetchDiscoverFeed(
      userId: SupabaseService.currentUserId,
      userLatitude: _userLatitude,
      userLongitude: _userLongitude,
      limit: _pageSize,
      offset: offset,
    );
  }

  Future<void> _loadUserLocation() async {
    final position = await _getCurrentLocation();
    if (!mounted || position == null) return;

    final latitudeChanged = _userLatitude != position.latitude;
    final longitudeChanged = _userLongitude != position.longitude;
    if (!latitudeChanged && !longitudeChanged) return;

    setState(() {
      _userLatitude = position.latitude;
      _userLongitude = position.longitude;
    });

    if (_topNavIndex == 1) {
      await loadPosts(silent: true);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  String get _emptyFeedMessage {
    if (_isFollowingTab) {
      if (SupabaseService.currentUserId == null) {
        return 'Sign in to see posts from people you follow.';
      }
      return 'Follow people to see their posts here.';
    }
    return 'No posts yet 🍽️';
  }

  void _handleTopNavTap(int index) {
    if (index == _topNavIndex) return;
    setState(() => _topNavIndex = index);
    loadPosts();
  }

  Future<void> loadPosts({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    setState(() {
      _error = null;
      _offset = 0;
      _hasMore = true;
      if (!silent) _posts = [];
    });
    try {
      final posts = await _fetchFeedPage(offset: 0);
      if (mounted) {
        setState(() {
          _posts = posts;
          _offset = posts.length;
          _hasMore = posts.length == _pageSize;
        });
      }
      _fetchUnreadCount();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scheduleViewportFillCheck();
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final more = await _fetchFeedPage(offset: _offset);
      if (mounted) {
        setState(() {
          _posts.addAll(more);
          _offset += more.length;
          _hasMore = more.length == _pageSize;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        _scheduleViewportFillCheck();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: Column(
        children: [
          _TopNavBar(
            selectedIndex: _topNavIndex,
            items: _topNavItems,
            unreadCount: _unreadNotifCount,
            onTap: _handleTopNavTap,
            onNotificationRefresh: _fetchUnreadCount,
          ),
          Expanded(child: _buildFeed()),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    if (_isLoading && _posts.isEmpty) {
      return const _HomeSkeleton();
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
                'Failed to load posts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: loadPosts,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          _emptyFeedMessage,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          _maybeLoadMore(notification.metrics);
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: loadPosts),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            sliver: SliverToBoxAdapter(
              child: _MasonryGrid(
                posts: _posts,
                onPostTap: (post) async {
                  final result = await Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => PostDetailScreen(post: post),
                    ),
                  );

                  if (result is PostModel && mounted) {
                    setState(() {
                      final index = _posts.indexWhere((p) => p.id == result.id);
                      if (index != -1) {
                        _posts[index] = result;
                      }
                    });
                  } else if (result == true && mounted) {
                    loadPosts(silent: true);
                  }
                },
              ),
            ),
          ),
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                child: _MasonryGridSkeleton(itemCount: 2),
              ),
            )
          else if (!_hasMore && _posts.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    '— End of posts —',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<String> items;
  final int unreadCount;
  final ValueChanged<int> onTap;
  final VoidCallback onNotificationRefresh;

  const _TopNavBar({
    required this.selectedIndex,
    required this.items,
    required this.unreadCount,
    required this.onTap,
    required this.onNotificationRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      color: CupertinoColors.white,
      padding: EdgeInsets.only(top: statusBarHeight),
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: Size.zero,
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const NotificationScreen(),
                  ),
                );
                if (result == true) onNotificationRefresh();
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    CupertinoIcons.bell,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CupertinoColors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(items.length, (i) {
                  final isSelected = selectedIndex == i;
                  return GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            items[i],
                            style: TextStyle(
                              fontSize: isSelected ? 16 : 14,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 3,
                            width: isSelected ? 20 : 0,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: Size.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const ExploreScreen()),
                );
              },
              child: const Icon(
                CupertinoIcons.search,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasonryGrid extends StatelessWidget {
  final List<PostModel> posts;
  final void Function(PostModel post) onPostTap;

  const _MasonryGrid({required this.posts, required this.onPostTap});

  @override
  Widget build(BuildContext context) {
    final leftCol = <PostModel>[];
    final rightCol = <PostModel>[];
    for (int i = 0; i < posts.length; i++) {
      (i.isEven ? leftCol : rightCol).add(posts[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: leftCol
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PostCard(post: p, onTap: () => onPostTap(p)),
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
                    child: PostCard(post: p, onTap: () => onPostTap(p)),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
        child: _MasonryGridSkeleton(itemCount: 6),
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
