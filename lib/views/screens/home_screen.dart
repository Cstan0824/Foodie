import 'package:flutter/cupertino.dart';
import '../../data/models/post_model.dart';
import '../../core/theme/app_theme.dart';
import '../shared/post_card.dart';
import 'post_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _topNavIndex = 1; // default: Discover
  final _scrollController = ScrollController();

  static const _topNavItems = ['Following', 'Discover', 'Nearby'];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(5, 8, 5, 24),
                  sliver: SliverToBoxAdapter(
                    child: _MasonryGrid(
                      posts: mockPosts,
                      onPostTap: (post) => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => PostDetailScreen(post: post),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
              onPressed: () {},
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
              onPressed: () {},
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
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: PostCard(post: p, onTap: () => onPostTap(p)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            children: rightCol
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: PostCard(post: p, onTap: () => onPostTap(p)),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
