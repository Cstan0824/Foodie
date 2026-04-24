import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/features/profile/screens/profile_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/data/models/profile_model.dart';
import 'package:taste_spot/data/repositories/profile_repository.dart';

class ConnectionsScreen extends StatefulWidget {
  final int initialTabIndex; // 0 for Following, 1 for Followers
  final String userId;

  const ConnectionsScreen({
    super.key,
    this.initialTabIndex = 0,
    required this.userId,
  });

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  late int _selectedTab;
  late PageController _pageController;
  
  bool _isLoading = true;
  List<Profile> _followingList = [];
  List<Profile> _followerList = [];
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Set of following IDs for the current logged-in user
  Set<String> _currentUserFollowingIds = {};
  final Set<String> _updatingUserIds = {}; // Track which user's follow state is being updated

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    _pageController = PageController(initialPage: _selectedTab);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final repo = ProfileRepository(Supabase.instance.client);
      
      // Load the lists for the user we are viewing
      final following = await repo.getFollowing(widget.userId);
      final followers = await repo.getFollowers(widget.userId);
      
      // Load current user's following list to show button states correctly
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final myFollowing = await repo.getFollowing(currentUser.id);
        _currentUserFollowingIds = myFollowing.map((p) => p.userId).toSet();
      }

      if (mounted) {
        setState(() {
          _followingList = following;
          _followerList = followers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(Profile user) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == user.userId) return;

    if (_updatingUserIds.contains(user.userId)) return;

    final isCurrentlyFollowing = _currentUserFollowingIds.contains(user.userId);
    
    setState(() {
      _updatingUserIds.add(user.userId);
      // Optimistic update
      if (isCurrentlyFollowing) {
        _currentUserFollowingIds.remove(user.userId);
      } else {
        _currentUserFollowingIds.add(user.userId);
      }
    });

    try {
      final repo = ProfileRepository(Supabase.instance.client);
      await repo.setFollowing(
        followerId: currentUserId,
        followingId: user.userId,
        isFollowing: !isCurrentlyFollowing,
      );
    } catch (e) {
      // Revert optimistic update on failure
      if (mounted) {
        setState(() {
          if (isCurrentlyFollowing) {
            _currentUserFollowingIds.add(user.userId);
          } else {
            _currentUserFollowingIds.remove(user.userId);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingUserIds.remove(user.userId);
        });
      }
    }
  }

  List<Profile> _getFilteredList(List<Profile> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((u) => 
      u.name.toLowerCase().contains(_searchQuery) || 
      (u.username ?? "").toLowerCase().contains(_searchQuery)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: Column(
        children: [
          _ConnectionNavBar(
            selectedIndex: _selectedTab,
            onTabChanged: (index) {
              setState(() => _selectedTab = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
              );
            },
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search user...',
              backgroundColor: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _selectedTab = index);
              },
              children: [
                _buildListContainer(_followingList, isFollowingTab: true),
                _buildListContainer(_followerList, isFollowingTab: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListContainer(List<Profile> list, {required bool isFollowingTab}) {
    if (_isLoading) return const _ConnectionsSkeleton();

    final filteredList = _getFilteredList(list);

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFollowingTab ? CupertinoIcons.person_add : CupertinoIcons.person_2, 
              size: 48, 
              color: AppColors.surface
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No results found for "$_searchQuery"'
                  : (isFollowingTab ? 'Not following anyone yet.' : 'No followers yet.'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      itemCount: filteredList.length,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(left: 82),
        child: Container(height: 0.5, color: AppColors.divider),
      ),
      itemBuilder: (context, index) {
        final user = filteredList[index];
        return _buildUserRow(context, user);
      },
    );
  }

  Widget _buildUserRow(BuildContext context, Profile user) {
    final bool isFollowed = _currentUserFollowingIds.contains(user.userId);
    final isCurrentUser = Supabase.instance.client.auth.currentUser?.id == user.userId;
    final isUpdating = _updatingUserIds.contains(user.userId);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => ProfileScreen(userId: user.userId),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
            child: ClipOval(
                child: (user.imageUrl != null && user.imageUrl!.isNotEmpty)
                    ? Image.network(
                        user.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          CupertinoIcons.person_fill,
                          color: AppColors.textLight,
                          size: 28,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.person_fill,
                        color: AppColors.textLight,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.username != null ? '@${user.username}' : 'User',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.bio!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Follow/Following Button
            if (!isCurrentUser)
              GestureDetector(
                onTap: () => _toggleFollow(user),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: isFollowed ? CupertinoColors.white : AppColors.primary,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isFollowed ? AppColors.divider : AppColors.primary,
                      width: 1,
                    ),
                  ),
                  child: isUpdating 
                      ? const CupertinoActivityIndicator(radius: 7)
                      : Text(
                          isFollowed ? 'Following' : 'Follow',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isFollowed ? AppColors.textSecondary : CupertinoColors.white,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionsSkeleton extends StatelessWidget {
  const _ConnectionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const SkeletonCircle(size: 52),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 120, height: 16),
                  SizedBox(height: 6),
                  Skeleton(width: 180, height: 12),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Skeleton(width: 80, height: 32, borderRadius: 16),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// CUSTOM NAVIGATION BAR
// ══════════════════════════════════════════════
class _ConnectionNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const _ConnectionNavBar({
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final tabs = ['Following', 'Followers'];

    return Container(
      color: CupertinoColors.white,
      padding: EdgeInsets.only(top: topPadding),
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Left: Back button
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: Size.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(
                CupertinoIcons.chevron_back,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            
            // Center: Tabs
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(tabs.length, (i) {
                  final isActive = selectedIndex == i;
                  return GestureDetector(
                    onTap: () => onTabChanged(i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            style: TextStyle(
                              fontSize: isActive ? 16 : 15,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                            child: Text(tabs[i]),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            height: 3,
                            width: isActive ? 16 : 0,
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

            // Right: Spacer to offset the back button
            const SizedBox(width: 56), 
          ],
        ),
      ),
    );
  }
}

