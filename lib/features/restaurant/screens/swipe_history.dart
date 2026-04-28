import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/utils/app_time.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/repositories/blind_box_repository.dart';
import 'package:taste_spot/features/restaurant/screens/restaurant_detail_screen.dart';

class BlindBoxSwipeHistoryScreen extends StatefulWidget {
  const BlindBoxSwipeHistoryScreen({super.key});

  @override
  State<BlindBoxSwipeHistoryScreen> createState() =>
      _BlindBoxSwipeHistoryScreenState();
}

class _BlindBoxSwipeHistoryScreenState
    extends State<BlindBoxSwipeHistoryScreen> {
  static const int _pageSize = 50;

  final ScrollController _scrollController = ScrollController();

  List<BlindBoxSwipeHistoryRestaurantItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  bool _isSelectionMode = false;
  final Set<String> _selectedRestaurantIds = {};
  bool _isDeletingSelected = false;
  static const String _hideInstructionsPreferenceKey =
      'blind_box_hide_instructions';

  bool get _hasUser {
    final userId = SupabaseService.currentUserId;
    return userId != null && userId.isNotEmpty;
  }

  bool get _isAllLoadedSelected {
    if (_items.isEmpty) return false;
    return _items.every(
      (item) => _selectedRestaurantIds.contains(item.restaurant.restaurantId),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadHistory(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 240) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = false;
        _error = null;
      });
      return;
    }

    if (refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
        _hasMore = true;
        _items = [];
      });
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
        _error = null;
      });
    }

    final offset = refresh ? 0 : _items.length;

    try {
      final nextItems = await BlindBoxRepository.instance
          .fetchSwipeHistoryRestaurants(
            userId: userId,
            limit: _pageSize,
            offset: offset,
          );

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _items = nextItems;
        } else {
          _items.addAll(nextItems);
        }
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = nextItems.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _enterSelectionMode(String restaurantId) {
    setState(() {
      _isSelectionMode = true;
      _selectedRestaurantIds.add(restaurantId);
    });
  }

  void _toggleSelection(String restaurantId) {
    setState(() {
      if (_selectedRestaurantIds.contains(restaurantId)) {
        _selectedRestaurantIds.remove(restaurantId);
      } else {
        _selectedRestaurantIds.add(restaurantId);
      }

      if (_selectedRestaurantIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedRestaurantIds.clear();
    });
  }

  void _toggleSelectAll() {
    if (_items.isEmpty) return;

    if (_isAllLoadedSelected) {
      setState(() {
        _isSelectionMode = true;
        _selectedRestaurantIds.clear();
      });
      return;
    }

    setState(() {
      _isSelectionMode = true;
      _selectedRestaurantIds
        ..clear()
        ..addAll(_items.map((item) => item.restaurant.restaurantId));
    });
  }

  void _showDeleteSelectedDialog() {
    final selectedCount = _selectedRestaurantIds.length;
    if (selectedCount == 0) return;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete selected history?'),
        content: Text(
          'This will remove $selectedCount restaurant(s) from your BlindBox history.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteSelectedHistory();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedHistory() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || userId.isEmpty) return;
    if (_selectedRestaurantIds.isEmpty) return;
    if (_isDeletingSelected) return;

    final selectedIds = _selectedRestaurantIds.toList();
    final deletedCount = selectedIds.length;

    setState(() {
      _isDeletingSelected = true;
    });

    try {
      for (final restaurantId in selectedIds) {
        await BlindBoxRepository.instance.deleteSwipeHistoryForRestaurant(
          userId: userId,
          restaurantId: restaurantId,
        );
      }

      if (!mounted) return;
      setState(() {
        _items = _items
            .where(
              (item) => !_selectedRestaurantIds.contains(
                item.restaurant.restaurantId,
              ),
            )
            .toList();
        _isSelectionMode = false;
        _selectedRestaurantIds.clear();
        _isDeletingSelected = false;
        if (_items.isEmpty) {
          _hasMore = false;
        }
      });

      if (!mounted) return;
      _showDeleteSelectedSuccess(deletedCount);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isDeletingSelected = false;
      });
    }
  }

  Future<void> _clearAllHistory() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      await BlindBoxRepository.instance.clearSwipeHistory(userId);
      if (!mounted) return;
      setState(() {
        _items = [];
        _hasMore = false;
        _error = null;
        _isSelectionMode = false;
        _selectedRestaurantIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _showClearAllDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Clear swipe history?'),
        content: const Text(
          'This will remove all restaurants from your BlindBox history.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _clearAllHistory();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInstructions({bool manual = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final shouldHide = prefs.getBool(_hideInstructionsPreferenceKey) ?? false;

    if (!mounted) return;
    if (!manual && shouldHide) return;

    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var doNotShowAgain = shouldHide;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('How BlindBox works'),
              content: Column(
                children: [
                  const SizedBox(height: 8),
                  const _BlindBoxInstructionRow(
                    icon: CupertinoIcons.xmark_circle,
                    text: 'Swipe left to skip',
                  ),
                  const _BlindBoxInstructionRow(
                    icon: CupertinoIcons.heart_circle,
                    text: 'Swipe right to save',
                  ),
                  const _BlindBoxInstructionRow(
                    icon: CupertinoIcons.photo_on_rectangle,
                    text: 'Tap left/right to switch photos',
                  ),
                  const _BlindBoxInstructionRow(
                    icon: CupertinoIcons.info_circle,
                    text: 'Tap center to view restaurant',
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setDialogState(() {
                        doNotShowAgain = !doNotShowAgain;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          doNotShowAgain
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          size: 18,
                          color: doNotShowAgain
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Do not show again',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    if (doNotShowAgain) {
                      await prefs.setBool(_hideInstructionsPreferenceKey, true);
                    } else if (shouldHide) {
                      await prefs.setBool(
                        _hideInstructionsPreferenceKey,
                        false,
                      );
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Got it'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        leading: _isSelectionMode
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _exitSelectionMode,
                child: const Text('Cancel'),
              )
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showInstructions(manual: true),
                child: const Icon(
                  CupertinoIcons.info_circle,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),
        middle: _isSelectionMode
            ? Text('${_selectedRestaurantIds.length} selected')
            : const Text('Swipe History'),
        trailing: _isSelectionMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _toggleSelectAll,
                    child: Text(
                      _isAllLoadedSelected ? 'Unselect All' : 'Select All',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed:
                        _selectedRestaurantIds.isEmpty || _isDeletingSelected
                        ? null
                        : _showDeleteSelectedDialog,
                    child: _isDeletingSelected
                        ? const CupertinoActivityIndicator(radius: 10)
                        : const Icon(
                            CupertinoIcons.trash,
                            size: 22,
                            color: AppColors.primary,
                          ),
                  ),
                ],
              )
            : _items.isNotEmpty
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showClearAllDialog,
                child: const Icon(
                  CupertinoIcons.trash,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              )
            : null,
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildSkeletonList();
    }

    if (_error != null && _items.isEmpty) {
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () => _loadHistory(refresh: true),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton.filled(
                      onPressed: () => _loadHistory(refresh: true),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      final message = _hasUser
          ? 'No swipe history yet.'
          : 'Sign in to view your swipe history.';
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () => _loadHistory(refresh: true),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => _loadHistory(refresh: true),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index >= _items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }

              final item = _items[index];
              return _buildHistoryRow(item);
            }, childCount: _items.length + (_isLoadingMore ? 1 : 0)),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(BlindBoxSwipeHistoryRestaurantItem item) {
    final restaurant = item.restaurant;
    final coverUrl = restaurant.imageUrls.isNotEmpty
        ? restaurant.imageUrls.first
        : null;
    final cuisine = restaurant.mainCuisineId ?? '-';
    final lastSwiped = _formatRelativeTime(item.lastSwipedAt);
    final isSelected = _selectedRestaurantIds.contains(restaurant.restaurantId);
    final backgroundColor = _isSelectionMode && isSelected
        ? AppColors.primary.withAlpha(16)
        : AppColors.cardBackground;
    final borderColor = _isSelectionMode && isSelected
        ? AppColors.primary.withAlpha(80)
        : AppColors.divider;
    final trailingIcon = _isSelectionMode
        ? (isSelected
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.circle)
        : CupertinoIcons.chevron_right;
    final trailingColor = _isSelectionMode
        ? (isSelected ? AppColors.primary : AppColors.textSecondary)
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(restaurant.restaurantId);
        } else {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) =>
                  RestaurantDetailScreen(restaurantId: restaurant.restaurantId),
            ),
          );
        }
      },
      onLongPress: () {
        if (_isSelectionMode) {
          _toggleSelection(restaurant.restaurantId);
        } else {
          _enterSelectionMode(restaurant.restaurantId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            _buildThumbnail(coverUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$cuisine • $lastSwiped',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(trailingIcon, size: 20, color: trailingColor),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? coverUrl) {
    if (coverUrl == null || coverUrl.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          CupertinoIcons.photo,
          color: AppColors.textLight,
          size: 22,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(coverUrl, width: 56, height: 56, fit: BoxFit.cover),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final difference = AppTime.differenceFromNowGmt8(dateTime);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays == 1) return 'yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    final months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final gmt8Date = AppTime.toGmt8(dateTime);
    final month = months[gmt8Date.month - 1];
    return '$month ${gmt8Date.day}, ${gmt8Date.year}';
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: const Row(
            children: [
              Skeleton(width: 56, height: 56, borderRadius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 160, height: 14, borderRadius: 6),
                    SizedBox(height: 8),
                    Skeleton(width: 120, height: 12, borderRadius: 6),
                  ],
                ),
              ),
              SizedBox(width: 10),
              SkeletonCircle(size: 20),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteSelectedSuccess(int deletedCount) {
    if (deletedCount <= 0) return;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Deleted'),
        content: Text(
          'Removed $deletedCount restaurant(s) from your BlindBox history.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}

class _BlindBoxInstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BlindBoxInstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
