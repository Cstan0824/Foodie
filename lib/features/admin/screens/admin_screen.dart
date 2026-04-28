import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/repositories/dashboard_repository.dart';
import 'package:taste_spot/features/admin/post_management/screens/post_management_screen.dart';
import 'package:taste_spot/features/admin/screens/admin_profile.dart';
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
        return _DashboardTab(
          onSelectTab: (i) => setState(() => _selectedTab = i),
        );
      case 1:
        return const PostManagementScreen();
      case 2:
        return const RestaurantManagementScreen();
      case 3:
        return const AdminProfileScreen();
      default:
        return _DashboardTab(
          onSelectTab: (i) => setState(() => _selectedTab = i),
        );
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
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

class _DashboardTab extends StatefulWidget {
  final ValueChanged<int> onSelectTab;

  const _DashboardTab({required this.onSelectTab});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  late Future<DashboardSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = DashboardRepository.instance.fetchDashboardSummary(
      activityLimit: 8,
    );
  }

  Future<void> _refresh() async {
    final future = DashboardRepository.instance.fetchDashboardSummary(
      activityLimit: 8,
    );
    setState(() => _summaryFuture = future);
    await future;
  }

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
        ),
        CupertinoSliverRefreshControl(onRefresh: _refresh),
        SliverToBoxAdapter(
          child: FutureBuilder<DashboardSummary>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _DashboardLoadingState();
              }

              if (snapshot.hasError && !snapshot.hasData) {
                return _DashboardErrorState(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }

              final summary = snapshot.requireData;
              return _DashboardContent(
                summary: summary,
                isRefreshing:
                    snapshot.connectionState == ConnectionState.waiting,
                onSelectTab: widget.onSelectTab,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardSummary summary;
  final bool isRefreshing;
  final ValueChanged<int> onSelectTab;

  const _DashboardContent({
    required this.summary,
    required this.isRefreshing,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final stats = summary.stats;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GreetingCard(
            attentionCount: stats.needsAttentionCount,
            isRefreshing: isRefreshing,
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Overview'),
          const SizedBox(height: 12),
          _StatsGrid(stats: stats),
          const SizedBox(height: 20),
          const _SectionTitle('Needs Attention'),
          const SizedBox(height: 12),
          _NeedsAttentionList(
            stats: stats,
            onReportsTap: () => onSelectTab(1),
            onRestaurantsTap: () => onSelectTab(2),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Recent Activity'),
          const SizedBox(height: 12),
          _RecentActivityList(activities: summary.recentActivities),
          const SizedBox(height: 20),
          const _SectionTitle('Quick Actions'),
          const SizedBox(height: 12),
          _QuickActions(
            onReportsTap: () => onSelectTab(1),
            onRestaurantApprovalsTap: () => onSelectTab(2),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GreetingSkeleton(),
          SizedBox(height: 20),
          _SectionTitle('Overview'),
          SizedBox(height: 12),
          _StatsGridSkeleton(),
          SizedBox(height: 20),
          _SectionTitle('Needs Attention'),
          SizedBox(height: 12),
          _AttentionListSkeleton(),
          SizedBox(height: 20),
          _SectionTitle('Recent Activity'),
          SizedBox(height: 12),
          _ActivityListSkeleton(),
          SizedBox(height: 20),
          _SectionTitle('Quick Actions'),
          SizedBox(height: 12),
          _QuickActionsSkeleton(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GreetingSkeleton extends StatelessWidget {
  const _GreetingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 110, height: 13, borderRadius: 4),
                SizedBox(height: 8),
                Skeleton(width: 70, height: 22, borderRadius: 5),
                SizedBox(height: 10),
                Skeleton(width: 220, height: 13, borderRadius: 4),
              ],
            ),
          ),
          SkeletonCircle(size: 52),
        ],
      ),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  const _StatsGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (_, _) => const _StatCardSkeleton(),
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  const _StatCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Skeleton(width: 34, height: 34, borderRadius: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 64, height: 20, borderRadius: 5),
              SizedBox(height: 7),
              Skeleton(width: 90, height: 11, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttentionListSkeleton extends StatelessWidget {
  const _AttentionListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: List.generate(5, (i) {
          final isLast = i == 4;
          return Column(
            children: [
              const _AttentionRowSkeleton(),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Container(height: 0.5, color: AppColors.divider),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _AttentionRowSkeleton extends StatelessWidget {
  const _AttentionRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Skeleton(width: 32, height: 32, borderRadius: 8),
          SizedBox(width: 12),
          Expanded(child: Skeleton(height: 13, borderRadius: 4)),
          SizedBox(width: 24),
          Skeleton(width: 28, height: 16, borderRadius: 4),
        ],
      ),
    );
  }
}

class _ActivityListSkeleton extends StatelessWidget {
  const _ActivityListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: List.generate(4, (i) {
          final isLast = i == 3;
          return Column(
            children: [
              const _ActivityRowSkeleton(),
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

class _ActivityRowSkeleton extends StatelessWidget {
  const _ActivityRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Skeleton(width: 36, height: 36, borderRadius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 150, height: 13, borderRadius: 4),
                SizedBox(height: 7),
                Skeleton(width: double.infinity, height: 12, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 16),
          Skeleton(width: 38, height: 11, borderRadius: 4),
        ],
      ),
    );
  }
}

class _QuickActionsSkeleton extends StatelessWidget {
  const _QuickActionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _QuickActionButtonSkeleton()),
        SizedBox(width: 12),
        Expanded(child: _QuickActionButtonSkeleton()),
      ],
    );
  }
}

class _QuickActionButtonSkeleton extends StatelessWidget {
  const _QuickActionButtonSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: const Column(
        children: [
          Skeleton(width: 24, height: 24, borderRadius: 6),
          SizedBox(height: 8),
          Skeleton(width: 96, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _DashboardErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: Color(0xFFFF9500),
              size: 30,
            ),
            const SizedBox(height: 12),
            const Text(
              'Dashboard data could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final int attentionCount;
  final bool isRefreshing;

  const _GreetingCard({
    required this.attentionCount,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final attentionText = attentionCount == 0
        ? 'No pending actions right now.'
        : '$attentionCount item${attentionCount == 1 ? '' : 's'} need attention today.';

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
              children: [
                const Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isRefreshing ? 'Refreshing dashboard data...' : attentionText,
                  style: const TextStyle(
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
  final DashboardStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        label: 'Active Posts',
        value: _formatCount(stats.activePosts),
        icon: CupertinoIcons.doc_text_fill,
        color: const Color(0xFF5856D6),
      ),
      _StatItem(
        label: 'Restaurants',
        value: _formatCount(stats.totalRestaurants),
        icon: CupertinoIcons.building_2_fill,
        color: const Color(0xFF34C759),
      ),
      _StatItem(
        label: 'Users',
        value: _formatCount(stats.totalUsers),
        icon: CupertinoIcons.person_2_fill,
        color: const Color(0xFF007AFF),
      ),
      _StatItem(
        label: 'Pending Reports',
        value: _formatCount(stats.pendingReports),
        icon: CupertinoIcons.flag_fill,
        color: const Color(0xFFFF9500),
      ),
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (_, i) => _StatCard(item: items[i]),
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

class _NeedsAttentionList extends StatelessWidget {
  final DashboardStats stats;
  final VoidCallback onReportsTap;
  final VoidCallback onRestaurantsTap;

  const _NeedsAttentionList({
    required this.stats,
    required this.onReportsTap,
    required this.onRestaurantsTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _AttentionItem(
        label: 'Pending Reports',
        value: stats.pendingReports,
        icon: CupertinoIcons.flag_fill,
        color: const Color(0xFFFF3B30),
        onTap: onReportsTap,
      ),
      _AttentionItem(
        label: 'Restaurant Approvals',
        value: stats.pendingRestaurantApprovals,
        icon: CupertinoIcons.checkmark_seal_fill,
        color: const Color(0xFF34C759),
        onTap: onRestaurantsTap,
      ),
      _AttentionItem(
        label: 'Pending Posts',
        value: stats.pendingPosts,
        icon: CupertinoIcons.doc_text,
        color: const Color(0xFF5856D6),
        onTap: onReportsTap,
      ),
      _AttentionItem(
        label: 'Disabled Restaurants',
        value: stats.disabledRestaurants,
        icon: CupertinoIcons.building_2_fill,
        color: const Color(0xFFFF9500),
        onTap: onRestaurantsTap,
      ),
      _AttentionItem(
        label: 'Blocked Comments',
        value: stats.blockedComments,
        icon: CupertinoIcons.chat_bubble_2_fill,
        color: const Color(0xFFAF52DE),
        onTap: onReportsTap,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              _AttentionRow(item: item),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Container(height: 0.5, color: AppColors.divider),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _AttentionItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AttentionItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _AttentionRow extends StatelessWidget {
  final _AttentionItem item;

  const _AttentionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              _formatCount(item.value),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: item.value > 0 ? item.color : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textLight,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<DashboardActivityItem> activities;

  const _RecentActivityList({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: const Text(
          'No recent activity yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: List.generate(activities.length, (i) {
          final item = activities[i];
          final visual = _activityVisual(item.type);
          final isLast = i == activities.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: visual.color.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(visual.icon, color: visual.color, size: 18),
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
                    Text(
                      _formatTimeAgo(item.createdAt),
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

class _ActivityVisual {
  final IconData icon;
  final Color color;

  const _ActivityVisual({required this.icon, required this.color});
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onReportsTap;
  final VoidCallback onRestaurantApprovalsTap;

  const _QuickActions({
    required this.onReportsTap,
    required this.onRestaurantApprovalsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: CupertinoIcons.checkmark_shield_fill,
            label: 'Review Reports',
            color: const Color(0xFFFF3B30),
            onTap: onReportsTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: CupertinoIcons.checkmark_seal_fill,
            label: 'Review Approvals',
            color: const Color(0xFF34C759),
            onTap: onRestaurantApprovalsTap,
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

_ActivityVisual _activityVisual(String type) {
  switch (type) {
    case DashboardActivityItem.restaurantType:
      return const _ActivityVisual(
        icon: CupertinoIcons.building_2_fill,
        color: Color(0xFF34C759),
      );
    case DashboardActivityItem.restaurantApprovalType:
      return const _ActivityVisual(
        icon: CupertinoIcons.checkmark_seal_fill,
        color: Color(0xFFFF9500),
      );
    case DashboardActivityItem.reportType:
      return const _ActivityVisual(
        icon: CupertinoIcons.flag_fill,
        color: Color(0xFFFF3B30),
      );
    case DashboardActivityItem.userType:
      return const _ActivityVisual(
        icon: CupertinoIcons.person_badge_plus_fill,
        color: Color(0xFF007AFF),
      );
    case DashboardActivityItem.commentType:
      return const _ActivityVisual(
        icon: CupertinoIcons.chat_bubble_2_fill,
        color: Color(0xFFAF52DE),
      );
    case DashboardActivityItem.postType:
    default:
      return const _ActivityVisual(
        icon: CupertinoIcons.doc_text_fill,
        color: Color(0xFF5856D6),
      );
  }
}

String _formatTimeAgo(DateTime? createdAt) {
  if (createdAt == null) return 'Unknown';

  final diff = DateTime.now().difference(createdAt);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365}y ago';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30}mo ago';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

String _formatCount(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer(sign);

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }

  return buffer.toString();
}
