import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedTab = 0;

  static const _userName = 'Walton G.';
  static const _userHandle = '@waltonfoodieKL';
  static const _userBio =
      'Food explorer | Bouldering enthusiast\nKL based - Discovering hidden gems';
  static const _avatarUrl = 'https://i.pravatar.cc/200?img=12';
  static const _postsCount = 24;
  static const _followersCount = 1243;
  static const _followingCount = 318;

  String _formatCount(int count) {
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
            delegate: _IconTabBarDelegate(
              selectedTab: _selectedTab,
              onTabChanged: (i) => setState(() => _selectedTab = i),
            ),
          ),
          _buildSliverGrid(context),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }

  // ===================================================
  // PROFILE SECTION
  // ===================================================
  Widget _buildProfileSection(BuildContext context) {
    final statusH = MediaQuery.of(context).padding.top;
    return Container(
      color: CupertinoColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: statusH),

          // Top bar: handle left + settings right
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      _userHandle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(10),
                    minimumSize: Size.zero,
                    onPressed: () => _showSettings(context),
                    child: const Icon(
                      CupertinoIcons.settings,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar + stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(),
                const SizedBox(width: 28),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCol(
                        value: _formatCount(_postsCount),
                        label: 'Posts',
                        onTap: () {},
                      ),
                      _StatCol(
                        value: _formatCount(_followersCount),
                        label: 'Followers',
                        onTap: () {},
                      ),
                      _StatCol(
                        value: _formatCount(_followingCount),
                        label: 'Following',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Name + bio
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _userBio,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _OutlinedButton(
                    label: 'Edit Profile',
                    onTap: () => _showEditProfile(context),
                  ),
                ),
                const SizedBox(width: 8),
                _OutlinedIconButton(
                  icon: CupertinoIcons.person_badge_plus,
                  onTap: () {},
                ),
              ],
            ),
          ),

          Container(height: 0.5, color: AppColors.divider),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: ClipOval(
        child: Image.network(
          _avatarUrl,
          width: 86,
          height: 86,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 86,
            height: 86,
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
  // 3-COLUMN GRID
  // ===================================================
  Widget _buildSliverGrid(BuildContext context) {
    final posts = _currentPosts;

    if (posts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = posts[index];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => PostDetailScreen(post: post),
              ),
            ),
            child: Container(
              color: AppColors.surface,
              child: Image.network(
                post.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.surface,
                  child: const Icon(
                    CupertinoIcons.photo,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
          );
        },
        childCount: posts.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
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

  void _showEditProfile(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 380,
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _EditField(label: 'Name', value: _userName),
                  const SizedBox(height: 12),
                  _EditField(label: 'Bio', value: _userBio),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Save Changes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================
// ICON TAB BAR — Instagram style, red underline
// ===================================================
class _IconTabBarDelegate extends SliverPersistentHeaderDelegate {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  static const _icons = [
    CupertinoIcons.square_grid_2x2_fill,
    CupertinoIcons.bookmark_fill,
    CupertinoIcons.heart_fill,
  ];

  const _IconTabBarDelegate({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: CupertinoColors.white,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: List.generate(_icons.length, (i) {
                final active = i == selectedTab;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTabChanged(i),
                    child: Center(
                      child: Icon(
                        _icons[i],
                        size: 22,
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.textLight,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Row(
            children: List.generate(_icons.length, (i) {
              return Expanded(
                child: Container(
                  height: 1.5,
                  color: i == selectedTab
                      ? AppColors.primary
                      : const Color(0xFFEEEEEE),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 44;

  @override
  double get minExtent => 44;

  @override
  bool shouldRebuild(covariant _IconTabBarDelegate old) =>
      old.selectedTab != selectedTab;
}

// ===================================================
// HELPER WIDGETS
// ===================================================

class _StatCol extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatCol({
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlinedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.tabBarBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _OutlinedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _OutlinedIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.tabBarBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: AppColors.textPrimary),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final String value;

  const _EditField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          placeholder: label,
          controller: TextEditingController(text: value),
          padding: const EdgeInsets.all(12),
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.tabBarBorder, width: 0.5),
          ),
        ),
      ],
    );
  }
}
