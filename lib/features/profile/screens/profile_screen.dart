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
import 'package:taste_spot/data/models/restaurant_approval_model.dart';
import 'package:taste_spot/data/repositories/restaurant_approval_repository.dart';
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
  int _selectedArchiveTab = 0;
  bool _isLoading = true;
  bool _isSettingsMenuOpen = false;
  bool _isAccountsMenuOpen = false;

  Profile? _userProfile;
  String? _profileImageUrl;
  List<PostModel> _myPosts = [];
  List<PostModel> _likedPosts = [];
  List<PostModel> _archivedPosts = [];
  List<RestaurantApprovalModel> _userApprovals = [];
  List<SavedAccount> _savedAccounts = [];
  int _followersCount = 0;
  int _followingCount = 0;

  bool _isFollowingUser = false;
  bool _isFollowUpdating = false;

  List<String> get _tabs => _isCurrentUser
      ? ['Posts', 'Liked', 'Pending', 'Archived']
      : ['Posts', 'Liked'];

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

      if (_isCurrentUser) {
        _archivedPosts = await PostRepository.instance.fetchArchivedPosts(
          userId: targetUserId,
        );
        _userApprovals = await RestaurantApprovalRepository.instance
            .fetchUserPendingApprovals(userId: targetUserId);
      } else {
        _archivedPosts = [];
        _userApprovals = [];
      }

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
    if (!mounted) return;
    final currentId = Supabase.instance.client.auth.currentUser?.id;

    setState(() => _isLoading = true);
    try {
      if (userId == currentId) {
        // If it's the current account, refresh session and data
        await Supabase.instance.client.auth.refreshSession();
        await _fetchProfileData(silent: false);
        return;
      }

      await AccountService.switchAccount(userId);
      // Give Supabase a moment to update the local session state
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        // Reset navigation to MainShell with the new account context
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => MainShell()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error switching account: $e');
      final errStr = e.toString();
      if (errStr.contains('refresh_token_not_found') ||
          errStr.contains('Invalid Refresh Token')) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Session Expired'),
              content: const Text(
                'Please sign in again to access this account.',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _addAccount();
                  },
                ),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addAccount() async {
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
      _followersCount = (_followersCount + (nextState ? 1 : -1)).clamp(
        0,
        99999999,
      );
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
          _followersCount = (_followersCount + (nextState ? -1 : 1)).clamp(
            0,
            99999999,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isFollowUpdating = false);
    }
  }

  void _shareProfile() {
    final userId = _userProfile?.userId;
    if (userId == null) return;

    // Using Supabase as a redirector to avoid NXDOMAIN errors in browsers
    final String deepLink =
        'https://wjwfqwvrynyfqbjkqmah.supabase.co/auth/v1/callback?redirect_to=io.supabase.tastespot://profile/$userId';

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
          return _likedPosts;
        case 2:
          return []; // Handled by _buildPendingApprovalsSliver
        case 3:
          return _archivedPosts;
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

  bool get _showsArchivedDesign => _isCurrentUser && _selectedTab == 3;
  bool get _showsPendingDesign => _isCurrentUser && _selectedTab == 2;

  void _handleMainTabChanged(int index) {
    setState(() {
      _selectedTab = index;
    });
  }

  void _showImagePreview(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    showCupertinoModalPopup(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Center(
            child: Hero(
              tag: 'profile_image_hero',
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.width * 0.85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface,
                      child: const Icon(
                        CupertinoIcons.person_fill,
                        size: 100,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool anyMenuOpen = _isSettingsMenuOpen;

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
            if (_isCurrentUser)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () =>
                    setState(() => _isSettingsMenuOpen = !_isSettingsMenuOpen),
                child: Icon(
                  _isSettingsMenuOpen
                      ? CupertinoIcons.xmark
                      : CupertinoIcons.bars,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              )
            else
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {},
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
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
                CupertinoSliverRefreshControl(
                  onRefresh: () => _fetchProfileData(silent: true),
                ),
                SliverToBoxAdapter(child: _buildProfileSection(context)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TextTabBarDelegate(
                    selectedTab: _selectedTab,
                    onTabChanged: _handleMainTabChanged,
                    tabs: _tabs,
                  ),
                ),
                ..._buildContentSlivers(context),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),

            if (anyMenuOpen)
              GestureDetector(
                onTap: () => setState(() {
                  _isSettingsMenuOpen = false;
                }),
                child: Container(color: Colors.black.withAlpha(20)),
              ),

            _buildSettingsDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameHeader() {
    if (_isLoading && _userProfile == null) {
      return const Skeleton(width: 100, height: 16, borderRadius: 4);
    }
    return GestureDetector(
      onTap: _isCurrentUser ? () => _showAccountsSheet(context) : null,
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
              _isAccountsMenuOpen
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              size: 12,
              color: AppColors.textPrimary,
            ),
          ],
        ],
      ),
    );
  }

  void _showAccountsSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      barrierColor: Colors.black.withAlpha(100),
      builder: (modalContext) => Container(
        padding: EdgeInsets.only(
          top: 12,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom + 40,
        ),
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Manage Accounts',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    ..._savedAccounts.map((account) {
                      final isCurrent =
                          account.userId ==
                          Supabase.instance.client.auth.currentUser?.id;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(modalContext);
                          _switchAccount(account.userId);
                        },
                        child: _buildAccountOption(
                          account.username ?? 'user',
                          account.avatarUrl ?? '',
                          isSelected: isCurrent,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            _buildMenuAction(
              'Add Account',
              CupertinoIcons.plus_circle,
              onTap: () {
                Navigator.pop(modalContext);
                _addAccount();
              },
            ),
            const SizedBox(height: 8),
            _buildMenuAction(
              'Log Out All Accounts',
              CupertinoIcons.square_arrow_right,
              isDestructive: true,
              onTap: () async {
                Navigator.pop(modalContext);
                for (var acc in _savedAccounts) {
                  await AccountService.removeAccount(acc.userId);
                }
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    CupertinoPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountOption(
    String username,
    String avatar, {
    bool isSelected = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withAlpha(15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: (avatar.isNotEmpty)
                  ? Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        CupertinoIcons.person_fill,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.person_fill,
                      size: 16,
                      color: AppColors.textLight,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              CupertinoIcons.checkmark_alt,
              size: 16,
              color: AppColors.primary,
            ),
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
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuAction(
                  'Settings',
                  CupertinoIcons.settings,
                  onTap: () => Navigator.of(
                    context,
                  ).push(CupertinoPageRoute(builder: (_) => SettingsScreen())),
                ),
                _buildMenuAction(
                  'Privacy',
                  CupertinoIcons.lock_shield,
                  onTap: () => Navigator.of(
                    context,
                  ).push(CupertinoPageRoute(builder: (_) => PrivacyScreen())),
                ),
                _buildMenuAction(
                  'Help & Feedback',
                  CupertinoIcons.question_circle,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => HelpFeedbackScreen()),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 0.5, color: AppColors.divider),
                ),
                _buildMenuAction(
                  'Logout',
                  CupertinoIcons.power,
                  isDestructive: true,
                  onTap: () async {
                    setState(() => _isSettingsMenuOpen = false);
                    await Supabase.instance.client.auth.signOut();
                    if (mounted) {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushAndRemoveUntil(
                        CupertinoPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuAction(
    String label,
    IconData icon, {
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final Color color = isDestructive
        ? CupertinoColors.systemRed
        : AppColors.textPrimary;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSettingsMenuOpen = false;
        });
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color.withAlpha(200)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () => _showImagePreview(_profileImageUrl),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withAlpha(40),
            width: 1.5,
          ),
        ),
        child: Hero(
          tag: 'profile_image_hero',
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
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        CupertinoIcons.person_fill,
                        size: 36,
                        color: AppColors.textLight,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.person_fill,
                      size: 36,
                      color: AppColors.textLight,
                    ),
            ),
          ),
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
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading && _userProfile == null) ...[
                      const Skeleton(width: 140, height: 22, borderRadius: 4),
                      const SizedBox(height: 8),
                      const Skeleton(width: 80, height: 14, borderRadius: 4),
                    ] else ...[
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
    final targetUserId =
        widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
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
        if (_isCurrentUser) ...[
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
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _shareProfile,
            child: Container(
              height: 40,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                CupertinoIcons.share,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ] else
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

  
  List<Widget> _buildContentSlivers(BuildContext context) {
    if (_showsArchivedDesign) {
      return [_buildArchivedPostsSliver(context)];
    }
    if (_showsPendingDesign) {
      return [_buildPendingApprovalsSliver(context)];
    }

    return [_buildPostsSliver(context)];
  }

  Widget _buildPendingApprovalsSliver(BuildContext context) {
    if (_isLoading && _userApprovals.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _PendingApprovalSkeleton(),
            ),
            childCount: 3,
          ),
        ),
      );
    }

    if (_userApprovals.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    CupertinoIcons.clock,
                    size: 30,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No pending approvals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8)
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PendingApprovalCard(item: _userApprovals[index]),
          ),
          childCount: _userApprovals.length,
        ),
      ),
    );
  }

  Widget _buildArchivedPostsSliver(BuildContext context) {
    if (_isLoading && _archivedPosts.isEmpty) {
      return const _GridSkeleton();
    }

    if (_archivedPosts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    CupertinoIcons.archivebox,
                    size: 30,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Archived posts will appear here',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(10),
      sliver: SliverToBoxAdapter(
        child: _ProfileMasonryGrid(
          posts: _archivedPosts,
          archived: true,
          showAuthor: true,
          onPostTap: (post) async {
            final result = await Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => PostDetailScreen(post: post, archived: true),
              ),
            );
            if (result == true) _fetchProfileData(silent: true);
          },
        ),
      ),
    );
  }

  Widget _buildPostsSliver(BuildContext context) {
    if (_isLoading) return const _GridSkeleton();
    final posts = _currentPosts;
    if (posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.doc_text,
                size: 48,
                color: AppColors.surface,
              ),
              const SizedBox(height: 12),
              Text(
                _selectedTab == 0 ? 'No posts yet' : 'No posts found',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
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
          showAuthor: _isCurrentUser && _selectedTab == 0,
          onPostTap: (post) async {
            final result = await Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => PostDetailScreen(post: post)),
            );
            if (result is PostModel && mounted) {
              setState(() {
                // Update in all relevant lists
                final myIdx = _myPosts.indexWhere((p) => p.id == result.id);
                if (myIdx != -1) _myPosts[myIdx] = result;

                final likedIdx = _likedPosts.indexWhere((p) => p.id == result.id);
                if (likedIdx != -1) {
                  if (_isCurrentUser && !result.isLiked) {
                    _likedPosts.removeAt(likedIdx);
                  } else {
                    _likedPosts[likedIdx] = result;
                  }
                } else if (_isCurrentUser && result.isLiked) {
                  _likedPosts.insert(0, result);
                }

                final archIdx = _archivedPosts.indexWhere((p) => p.id == result.id);
                if (archIdx != -1) _archivedPosts[archIdx] = result;
              });
            } else if (result == true) {
              _fetchProfileData(silent: true);
            }
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
            children: List.generate(
              3,
              (index) => const Column(
                children: [
                  Skeleton(width: 36, height: 20),
                  SizedBox(height: 6),
                  Skeleton(width: 54, height: 12),
                ],
              ),
            ),
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

class _PendingApprovalSkeleton extends StatelessWidget {
  const _PendingApprovalSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 42, height: 42, borderRadius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 120, height: 15),
                    SizedBox(height: 8),
                    Skeleton(width: 180, height: 12),
                  ],
                ),
              ),
              Skeleton(width: 80, height: 24, borderRadius: 999),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              SkeletonCircle(size: 14),
              SizedBox(width: 6),
              Skeleton(width: 100, height: 12),
            ],
          ),
        ],
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
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
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
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const CupertinoActivityIndicator(radius: 8)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPrimary
                      ? CupertinoColors.white
                      : AppColors.textPrimary,
                ),
              ),
      ),
    );
  }
}

class _PendingApprovalCard extends StatelessWidget {
  final RestaurantApprovalModel item;

  const _PendingApprovalCard({required this.item});

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Recently';
    final now = DateTime.now().toUtc();
    final diff = now.difference(date.toUtc());
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.clock_fill,
                  size: 20,
                  color: Color(0xFFFF9500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.address ?? 'No address provided',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Under Review',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                CupertinoIcons.info_circle,
                size: 14,
                color: AppColors.textLight,
              ),
              const SizedBox(width: 6),
              Text(
                'Submitted ${_timeAgo(item.detectedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileMasonryGrid extends StatelessWidget {
  final List<PostModel> posts;
  final bool archived;
  final bool showAuthor;
  final void Function(PostModel post) onPostTap;

  const _ProfileMasonryGrid({
    required this.posts,
    required this.onPostTap,
    this.archived = false,
    this.showAuthor = false,
  });

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
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProfilePostTile(
                      post: p,
                      archived: archived,
                      showAuthor: showAuthor,
                      onTap: () => onPostTap(p),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: rightCol
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProfilePostTile(
                      post: p,
                      archived: archived,
                      showAuthor: showAuthor,
                      onTap: () => onPostTap(p),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ProfilePostTile extends StatelessWidget {
  final PostModel post;
  final bool archived;
  final bool showAuthor;
  final VoidCallback onTap;

  const _ProfilePostTile({
    required this.post,
    required this.archived,
    required this.showAuthor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!archived) {
      return PostCard(post: post, showAuthor: showAuthor, onTap: onTap);
    }

    return Stack(
      children: [
        Opacity(
          opacity: 0.82,
          child: PostCard(post: post, showAuthor: showAuthor, onTap: onTap),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(155),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Archived',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.white,
                ),
              ),
            ),
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: CupertinoColors.white,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final tabW = constraints.maxWidth / tabs.length;
                // center the 24-px indicator under each tab
                final indicatorLeft = selectedTab * tabW + (tabW / 2) - 12;
                return Stack(
                  children: [
                    // ── Sliding red underline ──
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      left: indicatorLeft,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // ── Tab labels ──
                    Row(
                      children: List.generate(tabs.length, (i) {
                        final active = i == selectedTab;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onTabChanged(i),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                                child: Text(tabs[i]),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(height: 0.5, color: AppColors.divider),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 44;
  @override
  double get minExtent => 44;
  @override
  bool shouldRebuild(covariant _TextTabBarDelegate old) =>
      old.selectedTab != selectedTab || old.tabs != tabs;
}

class Divider extends StatelessWidget {
  final double height;
  final Color color;
  const Divider({super.key, required this.height, required this.color});
  @override
  Widget build(BuildContext context) => Container(height: height, color: color);
}
