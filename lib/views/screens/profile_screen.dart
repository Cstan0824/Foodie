import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedTab = 0;

  static const _userName = 'Walton G.';
  static const _userHandle = 'ID: waltonfoodieKL';
  static const _userBio =
      'Food explorer | Bouldering enthusiast\nKL based · Discovering hidden gems 🍜';
  static const _avatarUrl = 'https://i.pravatar.cc/200?img=12';
  static const _postsCount = 24;
  static const _followersCount = 1243;
  static const _followingCount = 318;

  static const _tabs = ['Notes', 'Liked', 'Saved'];

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  List<PostModel> get _currentPosts {
    switch (_selectedTab) {
      case 1:
        return mockPosts.reversed.toList();
      case 2:
        return mockPosts.sublist(0, 4);
      default:
        return mockPosts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildProfileSection(context)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TextTabBarDelegate(
              selectedTab: _selectedTab,
              onTabChanged: (i) => setState(() => _selectedTab = i),
              tabs: _tabs,
            ),
          ),
          _buildSliverGrid(context),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }

  // ===================================================
  // PROFILE SECTION — XHS centered style
  // ===================================================
  Widget _buildProfileSection(BuildContext context) {
    final statusH = MediaQuery.of(context).padding.top;
    return Container(
      color: CupertinoColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: statusH),

          // Top bar: back left, share + more right
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(10),
                    minimumSize: Size.zero,
                    onPressed: () {},
                    child: const Icon(
                      CupertinoIcons.chevron_back,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.all(10),
                    minimumSize: Size.zero,
                    onPressed: () {},
                    child: const Icon(
                      CupertinoIcons.share,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(10),
                    minimumSize: Size.zero,
                    onPressed: () => _showSettings(context),
                    child: const Icon(
                      CupertinoIcons.ellipsis_vertical,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar — centered with gradient ring
          _buildAvatar(),
          const SizedBox(height: 12),

          // Display name
          const Text(
            _userName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // XHS-style ID line
          const Text(
            _userHandle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // Stats row: Following | Fans | Notes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatItem(
                  value: _formatCount(_followingCount), label: 'Following'),
              const _StatDivider(),
              _StatItem(value: _formatCount(_followersCount), label: 'Fans'),
              const _StatDivider(),
              _StatItem(value: _formatCount(_postsCount), label: 'Notes'),
            ],
          ),
          const SizedBox(height: 16),

          // Bio — centered
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _userBio,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Interest tags
          const Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _TagChip(label: '🍜 Ramen'),
              _TagChip(label: '☕ Cafes'),
              _TagChip(label: '🧗 Bouldering'),
              _TagChip(label: '📍 KL'),
            ],
          ),
          const SizedBox(height: 18),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: 'Edit Profile',
                    filled: false,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _PillIconButton(
                  icon: CupertinoIcons.person_badge_plus,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 90,
      height: 90,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(2.5),
      child: ClipOval(
        child: Image.network(
          _avatarUrl,
          width: 85,
          height: 85,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.surface,
            child: const Icon(
              CupertinoIcons.person_fill,
              size: 44,
              color: AppColors.textLight,
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================
  // 2-COLUMN CARD GRID — XHS style
  // ===================================================
  Widget _buildSliverGrid(BuildContext context) {
    final posts = _currentPosts;

    if (posts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => PostDetailScreen(post: post),
                ),
              ),
              child: _XhsCard(post: post),
            );
          },
          childCount: posts.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
      ),
    );
  }

  // ===================================================
  // SHEETS
  // ===================================================
  void _showSettings(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Settings'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Account Settings'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Privacy'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Notifications'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Log Out'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

// ===================================================
// TEXT TAB BAR — XHS style with animated underline dot
// ===================================================
class _TextTabBarDelegate extends SliverPersistentHeaderDelegate {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final List<String> tabs;

  const _TextTabBarDelegate({
    required this.selectedTab,
    required this.onTabChanged,
    required this.tabs,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: CupertinoColors.white,
      child: Column(
        children: [
          Container(height: 0.5, color: AppColors.divider),
          Expanded(
            child: Row(
              children: List.generate(tabs.length, (i) {
                final active = i == selectedTab;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTabChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tabs[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w400,
                            color: active
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: active ? 20 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 46;

  @override
  double get minExtent => 46;

  @override
  bool shouldRebuild(covariant _TextTabBarDelegate old) =>
      old.selectedTab != selectedTab || old.tabs != tabs;
}

// ===================================================
// XHS CARD — image + title + like count
// ===================================================
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
            child: Image.network(
              post.imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface,
                child: const Center(
                  child: Icon(
                    CupertinoIcons.photo,
                    color: AppColors.textLight,
                    size: 28,
                  ),
                ),
              ),
            ),
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
}

// ===================================================
// HELPER WIDGETS
// ===================================================

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 28, color: AppColors.divider);
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : CupertinoColors.white,
          borderRadius: BorderRadius.circular(18),
          border: filled
              ? null
              : Border.all(color: AppColors.tabBarBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: filled ? CupertinoColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PillIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.tabBarBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}
