import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/admin/post_management/screens/post_management_screen.dart';
import 'package:taste_spot/features/admin/restaurant_management/screens/restaurant_management_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedTab = 0;

  static const List<_AdminTab> _tabs = [
    _AdminTab(
      label: 'Dashboard',
      icon: CupertinoIcons.chart_bar_square,
      activeIcon: CupertinoIcons.chart_bar_square_fill,
    ),
    _AdminTab(
      label: 'Reports',
      icon: CupertinoIcons.doc_text,
      activeIcon: CupertinoIcons.doc_text_fill,
    ),
    _AdminTab(
      label: 'Restaurants',
      icon: CupertinoIcons.building_2_fill,
      activeIcon: CupertinoIcons.building_2_fill,
    ),
    _AdminTab(
      label: 'Profile',
      icon: CupertinoIcons.person,
      activeIcon: CupertinoIcons.person_fill,
    ),
  ];

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return const _DashboardTab();
      case 1:
        return const PostManagementScreen();
      case 2:
        return const RestaurantManagementScreen();
      case 3:
        return const _PlaceholderTab(
          icon: CupertinoIcons.person_fill,
          title: 'Admin Profile',
          subtitle: 'Coming soon',
        );
      default:
        return const _DashboardTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          Expanded(child: _buildTabContent()),
          _AdminTabBar(
            selectedIndex: _selectedTab,
            tabs: _tabs,
            onTabSelected: (i) => setState(() => _selectedTab = i),
          ),
        ],
      ),
    );
  }
}

// ── Tab Bar ──────────────────────────────────────────────────────────────────

class _AdminTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _AdminTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _AdminTabBar extends StatelessWidget {
  final int selectedIndex;
  final List<_AdminTab> tabs;
  final ValueChanged<int> onTabSelected;

  const _AdminTabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: AppColors.tabBarBorder, width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final tab = tabs[i];
            final isSelected = i == selectedIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTabSelected(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? tab.activeIcon : tab.icon,
                      size: 22,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textLight,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Dashboard'),
          backgroundColor: AppColors.cardBackground,
          border: Border(
            bottom: BorderSide(color: AppColors.tabBarBorder, width: 0.5),
          ),
          trailing: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: AppColors.textLight,
              size: 24,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──
                _GreetingCard(),
                const SizedBox(height: 20),

                // ── Stats Grid ──
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                const _StatsGrid(),
                const SizedBox(height: 20),

                // ── Recent Activity ──
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                const _RecentActivityList(),
                const SizedBox(height: 20),

                // ── Quick Actions ──
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                const _QuickActions(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFF6B35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Here\'s what\'s happening today.',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: CupertinoColors.white.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.flame_fill,
              color: CupertinoColors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  static const List<_StatItem> _stats = [
    _StatItem(label: 'Total Posts', value: '1,284', icon: CupertinoIcons.doc_text_fill, color: Color(0xFF5856D6)),
    _StatItem(label: 'Restaurants', value: '342', icon: CupertinoIcons.building_2_fill, color: Color(0xFF34C759)),
    _StatItem(label: 'Users', value: '8,910', icon: CupertinoIcons.person_2_fill, color: Color(0xFF007AFF)),
    _StatItem(label: 'Reports', value: '17', icon: CupertinoIcons.flag_fill, color: Color(0xFFFF9500)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (_, i) => _StatCard(item: _stats[i]),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList();

  static const List<_ActivityItem> _activities = [
    _ActivityItem(
      icon: CupertinoIcons.doc_text_fill,
      iconColor: Color(0xFF5856D6),
      title: 'New post submitted',
      subtitle: 'Reviewed by @user123',
      time: '2m ago',
    ),
    _ActivityItem(
      icon: CupertinoIcons.building_2_fill,
      iconColor: Color(0xFF34C759),
      title: 'Restaurant added',
      subtitle: 'Sushi Nori — KL City',
      time: '15m ago',
    ),
    _ActivityItem(
      icon: CupertinoIcons.flag_fill,
      iconColor: Color(0xFFFF3B30),
      title: 'Post reported',
      subtitle: 'Spam content flagged',
      time: '1h ago',
    ),
    _ActivityItem(
      icon: CupertinoIcons.person_badge_plus_fill,
      iconColor: Color(0xFF007AFF),
      title: 'New user registered',
      subtitle: '@foodie_adventurer',
      time: '2h ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: List.generate(_activities.length, (i) {
          final item = _activities[i];
          final isLast = i == _activities.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.iconColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, color: item.iconColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 64),
                  child: Container(height: 0.5, color: AppColors.divider),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: CupertinoIcons.checkmark_shield_fill,
            label: 'Review Reports',
            color: const Color(0xFFFF3B30),
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.restaurant_menu,
            label: 'Add Restaurant',
            color: const Color(0xFF34C759),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(50), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder Tab ───────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(title),
          backgroundColor: AppColors.cardBackground,
          border: Border(
            bottom: BorderSide(color: AppColors.tabBarBorder, width: 0.5),
          ),
          trailing: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: AppColors.textLight,
              size: 24,
            ),
          ),
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 56, color: AppColors.textLight),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
