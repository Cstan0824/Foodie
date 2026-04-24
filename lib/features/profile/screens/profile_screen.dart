import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/models/profile_model.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/data/repositories/profile_repository.dart';
import 'package:taste_spot/features/auth/screens/login_screen.dart';
import 'package:taste_spot/features/post/screens/post_detail_screen.dart';
import 'package:taste_spot/features/profile/screens/connections_screen.dart';
import 'package:taste_spot/features/profile/screens/edit_profile_screen.dart';
import 'package:taste_spot/features/profile/screens/settings_screen.dart';
import 'package:taste_spot/features/profile/screens/privacy_screen.dart';
import 'package:taste_spot/features/profile/screens/help_feedback_screen.dart';
import 'package:taste_spot/core/widgets/post_card.dart';
import 'package:taste_spot/core/services/account_service.dart';
import 'package:taste_spot/main.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  int _selectedTab = 0;
  bool _isLoading = true;
  bool _isAccountsMenuOpen = false;
  bool _isSettingsMenuOpen = false;

  Profile? _userProfile;
  String? _profileImageUrl;
  List<PostModel> _myPosts = [];
  List<PostModel> _likedPosts = [];
  List<PostModel> _archivedPosts = [];
  List<SavedAccount> _savedAccounts = [];
  int _followersCount = 0;
  int _followingCount = 0;

  bool _isFollowingUser = false;
  bool _isFollowUpdating = false;

  List<String> get _tabs =>
      _isCurrentUser ? ['Posts', 'Archived', 'Liked'] : ['Posts', 'Liked'];

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final accounts = await AccountService.getSavedAccounts();
    if (mounted) {
      setState(() => _savedAccounts = accounts);
    }
  }

  @override
  void dispose() {
    _myPosts.clear();
    _likedPosts.clear();
    _archivedPosts.clear();
    _userProfile = null;
    _profileImageUrl = null;
    super.dispose();
  }

  bool get _isCurrentUser {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (widget.userId == null) return true;
    return currentUser?.id == widget.userId;
  }

  Future<void> loadUserPosts({bool silent = false}) async {
    await _fetchProfileData(silent: silent);
    await _loadSavedAccounts();
  }

  Future<void> _fetchProfileData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final targetUserId =
          widget.userId ??
          currentUser?.id ??
          '00000000-0000-0000-0000-000000000001';

      final profileRepo = ProfileRepository(Supabase.instance.client);
      _userProfile = await profileRepo.getProfile(targetUserId);
      _profileImageUrl = await profileRepo.getProfileImageUrl(targetUserId);

      _myPosts = await PostRepository.instance.fetchUserPosts(
        userId: targetUserId,
      );
      _followersCount = await profileRepo.getFollowersCount(targetUserId);
      _followingCount = await profileRepo.getFollowingCount(targetUserId);

      if (!_isCurrentUser) {
        final currentUserId = currentUser?.id;
        if (currentUserId != null) {
          _isFollowingUser = await profileRepo.checkIsFollowing(
            followerId: currentUserId,
            followingId: targetUserId,
          );
        }
      }

      _likedPosts = await PostRepository.instance.fetchLikedPosts(
        userId: targetUserId,
      );

      if (_isCurrentUser && _userProfile != null) {
        final session = Supabase.instance.client.auth.currentSession;
        await AccountService.saveAccount(
          userId: targetUserId,
          name: _userProfile!.name,
          username: _userProfile!.username,
          avatarUrl: _profileImageUrl,
          role: _userProfile!.role,
          sessionJson: session != null ? jsonEncode(session.toJson()) : null,
        );
        // Refresh the saved accounts list in state
        await _loadSavedAccounts();
      }
    } catch (e) {
      print('Error fetching profile data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _switchAccount(String userId) async {
    setState(() => _isLoading = true);
    try {
      await AccountService.switchAccount(userId);
      // MainShell will listen to auth change if we set it up, 
      // but here we can just reload the whole app or navigate.
      if (mounted) {
         Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
           CupertinoPageRoute(builder: (_) => MainShell()),
           (route) => false,
         );
      }
    } catch (e) {
      print('Error switching account: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addAccount() async {
    setState(() => _isAccountsMenuOpen = false);
    // Navigate to Login but don't clear existing sessions in Supabase (yet)
    // Actually Supabase.auth.signOut() clears the current session.
    // To add a new one, we just sign out and login. The old one is already saved in AccountService.
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _toggleFollowUser() async {
    if (_isFollowUpdating) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id;
    final targetUserId = widget.userId;

    if (currentUserId == null || targetUserId == null) return;
    if (currentUserId == targetUserId) return;

    final nextState = !_isFollowingUser;
    setState(() {
      _isFollowUpdating = true;
      _isFollowingUser = nextState;
      _followersCount = (_followersCount + (nextState ? 1 : -1)).clamp(0, 99999999);
    });

    final profileRepo = ProfileRepository(Supabase.instance.client);
    try {
      await profileRepo.setFollowing(
        followerId: currentUserId,
        followingId: targetUserId,
        isFollowing: nextState,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowingUser = !nextState;
          _followersCount = (_followersCount + (nextState ? -1 : 1)).clamp(0, 99999999);
        });
      }
    } finally {
      if (mounted) setState(() => _isFollowUpdating = false);
    }
  }

  void _shareProfile() {
    final userId = _userProfile?.userId;
    if (userId == null) return;
    
    // Using the same host structure that is proven to work in your Supabase config
    final String deepLink = 'io.supabase.tastespot://login-callback/profile?id=$userId';
    
    Share.share(
      'Check out my food journey on Taste Spot!\n$deepLink',
      subject: 'Taste Spot Profile',
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  List<PostModel> get _currentPosts {
    if (_isCurrentUser) {
      switch (_selectedTab) {
        case 1:
          return _archivedPosts;
        case 2:
          return _likedPosts;
        default:
          return _myPosts;
      }
    } else {
      switch (_selectedTab) {
        case 1:
          return _likedPosts;
        default:
          return _myPosts;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool anyMenuOpen = _isAccountsMenuOpen || _isSettingsMenuOpen;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: CupertinoColors.white,
        border: null,
        middle: _buildUsernameHeader(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _shareProfile,
              child: const Icon(CupertinoIcons.share, color: AppColors.textPrimary, size: 22),
            ),
            if (_isCurrentUser)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _isSettingsMenuOpen = !_isSettingsMenuOpen),
                child: Icon(
                  _isSettingsMenuOpen ? CupertinoIcons.xmark : CupertinoIcons.bars, 
                  color: AppColors.textPrimary, 
                  size: 24
                ),
              )
            else
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {},
                child: const Icon(CupertinoIcons.ellipsis, color: AppColors.textPrimary, size: 24),
              ),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
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

            // Background dim overlay when any menu is open
            if (anyMenuOpen)
              GestureDetector(
                onTap: () => setState(() {
                  _isAccountsMenuOpen = false;
                  _isSettingsMenuOpen = false;
                }),
                child: Container(
                  color: Colors.black.withAlpha(20),
                ),
              ),

            // ── Switch Account Dropdown ──
            _buildAccountsDropdown(),

            // ── More/Settings Dropdown ──
            _buildSettingsDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameHeader() {
    return GestureDetector(
      onTap: _isCurrentUser ? () => setState(() => _isAccountsMenuOpen = !_isAccountsMenuOpen) : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _userProfile?.username ?? 'user',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          if (_isCurrentUser) ...[
            const SizedBox(width: 2),
            Icon(
              _isAccountsMenuOpen ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down, 
              size: 12, 
              color: AppColors.textPrimary
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountsDropdown() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      top: _isAccountsMenuOpen ? 0 : -20,
      left: 0, right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isAccountsMenuOpen ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_isAccountsMenuOpen,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 25, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._savedAccounts.map((account) {
                  final isCurrent = account.userId == Supabase.instance.client.auth.currentUser?.id;
                  return GestureDetector(
                    onTap: isCurrent ? null : () => _switchAccount(account.userId),
                    child: _buildAccountOption(
                      account.username ?? 'user', 
                      account.avatarUrl ?? '', 
                      isSelected: isCurrent,
                    ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 0.5, color: AppColors.divider),
                ),
                _buildMenuAction(
                  'Add Account', 
                  CupertinoIcons.plus_circle, 
                  onTap: _addAccount,
                ),
                _buildMenuAction(
                  'Log Out', 
                  CupertinoIcons.square_arrow_right, 
                  isDestructive: true,
                  onTap: () async {
                    setState(() => _isAccountsMenuOpen = false);
                    final userId = Supabase.instance.client.auth.currentUser?.id;
                    if (userId != null) {
                      await AccountService.removeAccount(userId);
                    }
                    await Supabase.instance.client.auth.signOut();
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        CupertinoPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountOption(String username, String avatar, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withAlpha(15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: ClipOval(
              child: (avatar.isNotEmpty)
                  ? Image.network(
                      avatar, 
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.person_fill, size: 16, color: AppColors.textLight),
                    )
                  : const Icon(CupertinoIcons.person_fill, size: 16, color: AppColors.textLight),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username, 
              style: TextStyle(
                fontSize: 14, 
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary
              )
            ),
          ),
          if (isSelected)
            const Icon(CupertinoIcons.checkmark_alt, size: 16, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildSettingsDropdown() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      top: _isSettingsMenuOpen ? 0 : -20,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isSettingsMenuOpen ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_isSettingsMenuOpen,
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 25, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuAction('Settings', CupertinoIcons.settings, onTap: () {
                  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => SettingsScreen()));
                }),
                _buildMenuAction('Privacy', CupertinoIcons.lock_shield, onTap: () {
                  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => PrivacyScreen()));
                }),
                _buildMenuAction('Help & Feedback', CupertinoIcons.question_circle, onTap: () {
                  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => HelpFeedbackScreen()));
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 0.5, color: AppColors.divider),
                ),
                _buildMenuAction('Logout', CupertinoIcons.power, isDestructive: true, onTap: () async {
                   setState(() => _isSettingsMenuOpen = false);
                   await Supabase.instance.client.auth.signOut();
                   if (mounted) {
                     Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                       CupertinoPageRoute(builder: (_) => const LoginScreen()),
                       (route) => false,
                     );
                   }
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuAction(String label, IconData icon, {bool isDestructive = false, required VoidCallback onTap}) {
    final Color color = isDestructive ? CupertinoColors.systemRed : AppColors.textPrimary;
    return GestureDetector(
      onTap: () {
        setState(() { _isAccountsMenuOpen = false; _isSettingsMenuOpen = false; });
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color.withAlpha(200)),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    if (_isLoading) return const _ProfileHeaderSkeleton();

    return Container(
      color: CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar & Identity Column
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userProfile?.name ?? 'User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${_userProfile?.username ?? "user"}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                value: _formatCount(_myPosts.length),
                label: 'Posts',
                onTap: () => setState(() => _selectedTab = 0),
              ),
              Container(width: 1, height: 16, color: AppColors.divider),
              _StatItem(
                value: _formatCount(_followersCount),
                label: 'Followers',
                onTap: () => _navigateToConnections(1),
              ),
              Container(width: 1, height: 16, color: AppColors.divider),
              _StatItem(
                value: _formatCount(_followingCount),
                label: 'Following',
                onTap: () => _navigateToConnections(0),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          // Bio Section (Prettier & Minimal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              (_userProfile?.bio != null && _userProfile!.bio!.isNotEmpty)
                  ? _userProfile!.bio!
                  : 'Welcome to my flavor journey! 🍜',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary.withAlpha(180),
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
          ),

          const SizedBox(height: 20),

          _buildActionButtons(),
        ],
      ),
    );
  }

  void _navigateToConnections(int initialTab) {
    final targetUserId = widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (targetUserId == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ConnectionsScreen(
          initialTabIndex: initialTab,
          userId: targetUserId,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (_isCurrentUser)
          Expanded(
            child: _ActionPill(
              label: 'Edit Profile',
              onTap: () async {
                if (_userProfile == null) return;
                await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => EditProfileScreen(profile: _userProfile!),
                  ),
                );
                _fetchProfileData(silent: true);
              },
            ),
          )
        else
          Expanded(
            child: _ActionPill(
              label: _isFollowingUser ? 'Following' : 'Follow',
              isPrimary: !_isFollowingUser,
              isLoading: _isFollowUpdating,
              onTap: _toggleFollowUser,
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withAlpha(40), width: 1.5),
      ),
      child: Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
        ),
        child: ClipOval(
          child: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
              ? Image.network(
                  _profileImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(CupertinoIcons.person_fill, size: 36, color: AppColors.textLight),
                )
              : const Icon(CupertinoIcons.person_fill, size: 36, color: AppColors.textLight),
        ),
      ),
    );
  }

  Widget _buildSliverGrid(BuildContext context) {
    if (_isLoading) return const _GridSkeleton();

    final posts = _currentPosts;
    if (posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.doc_text, size: 48, color: AppColors.surface),
              const SizedBox(height: 12),
              Text(
                _selectedTab == 0 ? 'No posts yet' : 'No posts found',
                style: const TextStyle(color: AppColors.textLight, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(10),
      sliver: SliverToBoxAdapter(
        child: _ProfileMasonryGrid(
          posts: posts,
          onPostTap: (post) async {
            final result = await Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => PostDetailScreen(post: post)),
            );
            if (result == true) _fetchProfileData(silent: true);
          },
        ),
      ),
    );
  }
}

class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonCircle(size: 80),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 140, height: 22),
                    SizedBox(height: 8),
                    Skeleton(width: 80, height: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) => const Column(
              children: [
                Skeleton(width: 36, height: 20),
                SizedBox(height: 6),
                Skeleton(width: 54, height: 12),
              ],
            )),
          ),
          const SizedBox(height: 24),
          const Skeleton(width: double.infinity, height: 14),
          const SizedBox(height: 6),
          const Skeleton(width: 220, height: 14),
          const SizedBox(height: 24),
          const Skeleton(height: 40, borderRadius: 20),
        ],
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(10),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.7,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: Skeleton(borderRadius: 12)),
              const SizedBox(height: 8),
              const Skeleton(width: 100, height: 14),
              const SizedBox(height: 4),
              Skeleton(width: 60, height: 12, borderRadius: 4),
            ],
          ),
          childCount: 4,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatItem({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    this.isPrimary = false,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const CupertinoActivityIndicator(radius: 8)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? CupertinoColors.white : AppColors.textPrimary,
                ),
              ),
      ),
    );
  }
}

class _ProfileMasonryGrid extends StatelessWidget {
  final List<PostModel> posts;
  final void Function(PostModel post) onPostTap;

  const _ProfileMasonryGrid({required this.posts, required this.onPostTap});

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
            children: leftCol.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PostCard(post: p, onTap: () => onPostTap(p)),
            )).toList(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: rightCol.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PostCard(post: p, onTap: () => onPostTap(p)),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: CupertinoColors.white,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: List.generate(tabs.length, (i) {
                final active = i == selectedTab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTabChanged(i),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tabs[i],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              color: active ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // The red indicator sits on the border
                          Opacity(
                            opacity: active ? 1.0 : 0.0,
                            child: Container(
                              width: 24,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Container(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }

  @override double get maxExtent => 44;
  @override double get minExtent => 44;
  @override bool shouldRebuild(covariant _TextTabBarDelegate old) => old.selectedTab != selectedTab || old.tabs != tabs;
}

class Divider extends StatelessWidget {
  final double height;
  final Color color;
  const Divider({super.key, required this.height, required this.color});
  @override
  Widget build(BuildContext context) => Container(height: height, color: color);
}
