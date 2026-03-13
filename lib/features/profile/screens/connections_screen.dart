import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';

class ConnectionsScreen extends StatefulWidget {
  final int initialTabIndex; // 0 for Following, 1 for Followers

  const ConnectionsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  late int _selectedTab;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    _pageController = PageController(initialPage: _selectedTab);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Mock data
  final List<Map<String, dynamic>> _followingMatches = [
    {'name': 'Alex Chow', 'handle': '@alexchow', 'bio': 'Coffee addict ☕️', 'followed': true},
    {'name': 'Sarah Lee', 'handle': '@sarah_eats', 'bio': 'Exploring KL hotspots', 'followed': true},
    {'name': 'Jim Halpert', 'handle': '@jimmy_h', 'bio': 'Ramen lover 🍜', 'followed': true},
  ];

  final List<Map<String, dynamic>> _followerMatches = [
    {'name': 'Alex Chow', 'handle': '@alexchow', 'bio': 'Coffee addict ☕️', 'followed': true},
    {'name': 'Mike Ross', 'handle': '@mike_r', 'bio': 'Foodie forever', 'followed': false},
    {'name': 'Emma Stone', 'handle': '@emma_bakes', 'bio': 'Sweet tooth 🍰', 'followed': false},
    {'name': 'David Kim', 'handle': '@dkim', 'bio': 'Street food hunter', 'followed': true},
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Custom Sleek Navigation Bar
          _ConnectionNavBar(
            selectedIndex: _selectedTab,
            onTabChanged: (index) {
              setState(() => _selectedTab = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            },
          ),
          
          // Page View
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _selectedTab = index);
              },
              children: [
                _buildListContainer(_followingMatches, isFollowingTab: true),
                _buildListContainer(_followerMatches, isFollowingTab: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListContainer(List<Map<String, dynamic>> list, {required bool isFollowingTab}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isFollowingTab ? 'You are not following anyone yet.' : 'No followers yet.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final user = list[index];
        return _buildUserRow(context, user);
      },
    );
  }

  Widget _buildUserRow(BuildContext context, Map<String, dynamic> user) {
    final bool isFollowed = user['followed'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.divider,
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.person_solid, color: AppColors.textLight, size: 28),
          ),
          const SizedBox(width: 14),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${user['handle']} • ${user['bio']}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Follow/Following Button
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () {
              setState(() {
                user['followed'] = !isFollowed;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isFollowed ? AppColors.surface : AppColors.primary,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isFollowed ? AppColors.divider : AppColors.primary,
                  width: 1,
                ),
              ),
              child: Text(
                isFollowed ? 'Following' : 'Follow',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isFollowed ? AppColors.textSecondary : CupertinoColors.white,
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
    final tabs = ['Following', 'Fans'];

    return Container(
      color: AppColors.surface.withValues(alpha: 0.98),
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
