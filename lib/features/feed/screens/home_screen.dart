import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/post_card.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/features/notification/screens/notification_screen.dart';
import 'package:taste_spot/features/post/screens/post_detail_screen.dart';
import 'package:taste_spot/features/search/screens/explore_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _topNavIndex = 1; // default: Discover
  final _scrollController = ScrollController();

  static const _topNavItems = ['Following', 'Discover', 'Nearby'];
  static const _pageSize = 20;
  static const _paginationThreshold = 300.0;

  List<PostModel> _posts = [];
  bool _isLoading = true; // true only on initial load
  bool _isLoadingMore = false; // true when fetching the next page
  bool _hasMore = true; // false when we've reached the last page
  String? _error;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _loadPosts();
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

  // ── Initial load (or pull-to-refresh) ────────────────────────────────────
  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
      _posts = [];
    });
    try {
      final posts = await PostRepository.instance.fetchDiscoverPosts(
        limit: _pageSize,
        offset: 0,
      );
      if (mounted) {
        setState(() {
          _posts = posts;
          _offset = posts.length;
          _hasMore = posts.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scheduleViewportFillCheck();
      }
    }
  }

  // ── Load next page and append ─────────────────────────────────────────────
  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final more = await PostRepository.instance.fetchDiscoverPosts(
        limit: _pageSize,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          _posts.addAll(more);
          _offset += more.length;
          _hasMore = more.length == _pageSize;
        });
      }
    } catch (_) {
      // Silently fail on pagination errors — user can scroll again to retry
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
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // ── Top Navigation Bar ──
          _TopNavBar(
            selectedIndex: _topNavIndex,
            items: _topNavItems,
            onTap: (i) => setState(() => _topNavIndex = i),
          ),

          // ── Feed ──
          Expanded(child: _buildFeed()),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    // ── Initial loading spinner ──
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // ── Error with retry ──
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Failed to load posts',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: _loadPosts,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    // ── Empty state ──
    if (_posts.isEmpty) {
      return const Center(
        child: Text(
          'No posts yet 🍽️',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // ── Feed with infinite scroll ──
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          _maybeLoadMore(notification.metrics);
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Pull-to-refresh
          CupertinoSliverRefreshControl(onRefresh: _loadPosts),

          // Posts grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(5, 8, 5, 0),
            sliver: SliverToBoxAdapter(
              child: _MasonryGrid(
                posts: _posts,
                onPostTap: (post) => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => HeroMode(
                      enabled: false,
                      child: PostDetailScreen(post: post),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom indicator: loading spinner or "end of feed" message
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: _isLoadingMore
                  ? const Center(child: CupertinoActivityIndicator())
                  : _hasMore
                  ? const SizedBox.shrink()
                  : const Center(
                      child: Text(
                        '— You\'re all caught up 🎉 —',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
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

// ══════════════════════════════════════════════
//  TOP NAVIGATION BAR
//  🔔  |  Following · Discover · Nearby  |  🔍
// ══════════════════════════════════════════════
class _TopNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<String> items;
  final ValueChanged<int> onTap;

  const _TopNavBar({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
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
            bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // ── Left: Bell icon ──
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: Size.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const NotificationScreen(),
                  ),
                );
              },
              child: const Icon(
                CupertinoIcons.bell,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),

            // ── Center: Tab items ──
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
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              fontSize: isSelected ? 16 : 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            child: Text(items[i]),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
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

            // ── Right: Search icon ──
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

// ══════════════════════════════════════════════
//  2-COLUMN MASONRY GRID
// ══════════════════════════════════════════════
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
                    padding: const EdgeInsets.only(bottom: 5),
                    child: PostCard(post: p, onTap: () => onPostTap(p)),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            children: rightCol
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
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
