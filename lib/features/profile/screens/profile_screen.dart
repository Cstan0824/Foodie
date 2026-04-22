import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/models/profile_model.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/data/repositories/profile_repository.dart';
import 'package:taste_spot/features/auth/screens/login_screen.dart';
import 'package:taste_spot/features/post/screens/post_detail_screen.dart';
import 'package:taste_spot/features/profile/screens/connections_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedTab = 0;
  bool _isLoading = true;

  Profile? _userProfile;
  List<PostModel> _myPosts = [];
  List<PostModel> _likedPosts = [];

  static const _tabs = ['Notes', 'Liked'];
  String get _avatarUrl =>
      'https://i.pravatar.cc/200?u=${_userProfile?.userId ?? "guest"}';

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profileRepo = ProfileRepository(Supabase.instance.client);
        _userProfile = await profileRepo.getProfile(user.id);

        _myPosts = await PostRepository.instance.fetchPostsByUser(user.id);

        try {
          // Fetch Liked Posts
          final likesResponse = await Supabase.instance.client
              .from('likes')
              .select('post_Id')
              .eq('user_Id', user.id);

          if (likesResponse.isNotEmpty) {
            final List<dynamic> postIds = likesResponse
                .map((l) => l['post_Id'])
                .toList();

            // Build filter string manually or use .inFilter
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

            _likedPosts = (postsResponse as List<dynamic>)
                .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          print(
            'Optional Liked Posts query failed or table does not match: $e',
          );
        }
      }
    } catch (e) {
      print('Error fetching profile data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  List<PostModel> get _currentPosts {
    switch (_selectedTab) {
      case 1:
        return _likedPosts;
      default:
        return _myPosts;
    }
  }

  int get _notesCount => _myPosts.length;
  int get _followersCount => 0;
  int get _followingCount => 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: AppColors.background,
        border: null, // Removes bottom border to flow smoothly into header
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAccountsSheet(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _userProfile?.username ?? 'user',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_down,
                size: 14,
                color: AppColors.textPrimary,
              ),
            ],
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showSettingsSheet(context),
          child: const Icon(
            CupertinoIcons.gear,
            color: AppColors.textPrimary,
            size: 24,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
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
      ),
    );
  }

  // ===================================================
  // PROFILE SECTION — Clean Row-based Header
  // ===================================================
  Widget _buildProfileSection(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + Stats Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          value: _formatCount(_notesCount),
                          label: 'Notes',
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _StatItem(
                          value: _formatCount(_followersCount),
                          label: 'Followers',
                          onTap: () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) =>
                                  const ConnectionsScreen(initialTabIndex: 1),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _StatItem(
                          value: _formatCount(_followingCount),
                          label: 'Following',
                          onTap: () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) =>
                                  const ConnectionsScreen(initialTabIndex: 0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            _userProfile?.name ?? 'User',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Bio
          Text(
            _userProfile?.bio ?? 'No bio yet.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  label: 'Edit Profile',
                  filled: false,
                  onTap: () async {
                    if (_userProfile == null) return;
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            EditProfileScreen(profile: _userProfile!),
                      ),
                    );
                    _fetchProfileData();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillButton(
                  label: 'Share Profile',
                  filled: false,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 8),
              _PillIconButton(
                icon: CupertinoIcons.person_badge_plus,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),
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
    final emptyMessage = _selectedTab == 1
        ? 'No Liked Post yet'
        : 'No notes yet';

    if (posts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            emptyMessage,
            style: const TextStyle(
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
        delegate: SliverChildBuilderDelegate((context, index) {
          final post = posts[index];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => PostDetailScreen(post: post)),
            ),
            child: _XhsCard(post: post),
          );
        }, childCount: posts.length),
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

  void _showAccountsSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext sheetContext) => CupertinoActionSheet(
        title: const Text('Switch Account'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
            },
            child: Text('${_userProfile?.name ?? "User"} (Current)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
            },
            child: const Text('Add Account...'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(sheetContext); // Close the action sheet
              try {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    CupertinoPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                print('Error logging out: $e');
              }
            },
            child: const Text('Log Out'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(sheetContext);
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              // TODO: Open full settings page
              Navigator.pop(context);
            },
            child: const Text('Settings'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Help & Support'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
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
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
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
  final VoidCallback? onTap;

  const _StatItem({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
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
          borderRadius: BorderRadius.circular(8),
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.tabBarBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}
