import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';
import 'package:taste_spot/data/models/cuisine_model.dart';
import 'package:taste_spot/data/repositories/restaurant_repository.dart';
import 'package:taste_spot/data/models/restaurant_approval_model.dart';
import 'package:taste_spot/data/repositories/restaurant_approval_repository.dart';
import 'package:taste_spot/features/admin/restaurant_management/screens/view_restaurant_screen.dart';
import 'package:taste_spot/features/admin/restaurant_management/screens/add_edit_restaurant_screen.dart';

// ── Screen ───────────────────────────────────────────────────────────────────

class RestaurantManagementScreen extends StatefulWidget {
  const RestaurantManagementScreen({super.key});

  @override
  State<RestaurantManagementScreen> createState() => _RestaurantManagementScreenState();
}

class _RestaurantManagementScreenState extends State<RestaurantManagementScreen> 
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _tabAnim;

  final ScrollController _restScrollCtrl = ScrollController();
  final ScrollController _apprScrollCtrl = ScrollController();

  List<RestaurantModel> _restaurants = [];
  List<RestaurantApprovalModel> _approvals = [];
  List<CuisineModel> _cuisines = [];
  
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasMoreRestaurants = true;
  String? _error;

  bool _isLoadingApprovals = false;
  bool _isFetchingMoreApprovals = false;
  bool _hasMoreApprovals = true;
  String? _approvalsError;

  static const int _limit = 20;

  // Search & filter state
  String _searchQuery = '';
  String _statusFilter = 'all';   // all | active | disabled
  String _sourceFilter = 'all';   // all | admin | API | user-approved
  List<String> _cuisineFilters = [];

  final _repo = RestaurantRepository.instance;
  final _approvalRepo = RestaurantApprovalRepository.instance;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _restScrollCtrl.addListener(_onRestScroll);
    _apprScrollCtrl.addListener(_onApprScroll);
    
    _loadCuisines();
    _loadRestaurants();
    _loadApprovals();
  }

  @override
  void dispose() {
    _restScrollCtrl.dispose();
    _apprScrollCtrl.dispose();
    _tabAnim.dispose();
    super.dispose();
  }

  void _onRestScroll() {
    if (_restScrollCtrl.position.pixels >= _restScrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreRestaurants();
    }
  }

  void _onApprScroll() {
    if (_apprScrollCtrl.position.pixels >= _apprScrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreApprovals();
    }
  }

  void _switchTab(int index) {
    if (index == _tab) return;
    setState(() => _tab = index);
    if (index == 1) {
      _tabAnim.forward();
      if (_approvals.isEmpty && _approvalsError == null) _loadApprovals();
    } else {
      _tabAnim.reverse();
      if (_restaurants.isEmpty && _error == null) _loadRestaurants();
    }
  }

  Future<void> _loadApprovals({bool refresh = false}) async {
    if (refresh) {
      setState(() { _approvalsError = null; _hasMoreApprovals = true; });
    }
    setState(() { _isLoadingApprovals = true; _approvalsError = null; });
    try {
      final approvals = await _approvalRepo.fetchPendingApprovals(limit: _limit, offset: 0);
      if (!mounted) return;
      setState(() {
        _approvals = approvals;
        _isLoadingApprovals = false;
        _hasMoreApprovals = approvals.length == _limit;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _approvalsError = e.toString();
        _isLoadingApprovals = false;
      });
    }
  }

  Future<void> _loadMoreApprovals() async {
    if (_isFetchingMoreApprovals || !_hasMoreApprovals || _isLoadingApprovals) return;
    setState(() => _isFetchingMoreApprovals = true);
    try {
      final more = await _approvalRepo.fetchPendingApprovals(limit: _limit, offset: _approvals.length);
      if (!mounted) return;
      setState(() {
        _approvals.addAll(more);
        _hasMoreApprovals = more.length == _limit;
        _isFetchingMoreApprovals = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isFetchingMoreApprovals = false);
    }
  }

  Future<void> _loadCuisines() async {
    try {
      final cuisines = await _repo.fetchAllCuisines();
      if (!mounted) return;
      setState(() => _cuisines = cuisines);
    } catch (_) {}
  }

  Future<void> _loadRestaurants({bool refresh = false}) async {
    if (refresh) {
      setState(() { _error = null; _hasMoreRestaurants = true; });
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final restaurants = await _repo.fetchAllRestaurants(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        isDisabled: _statusFilter == 'all' ? null : _statusFilter == 'disabled',
        source: _sourceFilter == 'all' ? null : _sourceFilter,
        cuisineIds: _cuisineFilters.isEmpty ? null : _cuisineFilters,
        limit: _limit,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        _isLoading = false;
        _hasMoreRestaurants = restaurants.length == _limit;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreRestaurants() async {
    if (_isFetchingMore || !_hasMoreRestaurants || _isLoading) return;
    setState(() => _isFetchingMore = true);
    try {
      final more = await _repo.fetchAllRestaurants(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        isDisabled: _statusFilter == 'all' ? null : _statusFilter == 'disabled',
        source: _sourceFilter == 'all' ? null : _sourceFilter,
        cuisineIds: _cuisineFilters.isEmpty ? null : _cuisineFilters,
        limit: _limit,
        offset: _restaurants.length,
      );
      if (!mounted) return;
      setState(() {
        _restaurants.addAll(more);
        _hasMoreRestaurants = more.length == _limit;
        _isFetchingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  // Client-side filtering is no longer needed — server handles it.
  // We keep getter for consistent API in the build method.
  List<RestaurantModel> get _filteredRestaurants => _restaurants;

  void _clearFilters() {
    setState(() {
      _statusFilter = 'all';
      _sourceFilter = 'all';
      _cuisineFilters.clear();
    });
    _loadRestaurants();
  }

  bool get _hasActiveFilters =>
      _statusFilter != 'all' || _sourceFilter != 'all' || _cuisineFilters.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ──
        _buildHeader(context),
        // ── Content ──
        Expanded(child: _buildBody()),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, right: 16, bottom: 4,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Restaurant Management',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                _HeaderIconButton(
                  icon: CupertinoIcons.arrow_clockwise,
                  onTap: _loadRestaurants,
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
                _HeaderActionButton(
                  icon: CupertinoIcons.add,
                  label: 'Add',
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const AddEditRestaurantScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // ── Animated underline tab bar ──
          _SlideTabBar(
            labels: [
              'List ${_restaurants.isNotEmpty ? "(${_restaurants.length})" : ""}',
              'Approval ${_approvals.isNotEmpty ? "(${_approvals.length})" : ""}',
            ],
            selectedIndex: _tab,
            onTap: _switchTab,
          ),
          // ── Search bar ──
          if (_tab == 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoSearchTextField(
                placeholder: 'Search by name or address',
                onChanged: (v) { setState(() => _searchQuery = v); _loadRestaurants(); },
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            // ── Filters ──
            _buildFilterBar(),
          ],
          Container(height: 0.5, color: AppColors.divider),
        ],
      ),
    );
  }

  // ── Filter chips row ───────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10, left: 16, right: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Status
          _FilterChip(
            label: 'Status: ${_statusFilter.toUpperCase()}',
            isActive: _statusFilter != 'all',
            onTap: () => _showStatusPicker(),
          ),
          // Source
          _FilterChip(
            label: 'Source: ${_sourceFilter.toUpperCase()}',
            isActive: _sourceFilter != 'all',
            onTap: () => _showSourcePicker(),
          ),
          // Cuisine
          _FilterChip(
            label: _cuisineFilters.isEmpty
                ? 'Cuisine'
                : _cuisineFilters.length == 1
                    ? _cuisines.firstWhere((c) => c.id == _cuisineFilters.first, orElse: () => _cuisines.first).description
                    : '${_cuisineFilters.length} Cuisines',
            isActive: _cuisineFilters.isNotEmpty,
            onTap: () => _showCuisinePicker(),
          ),
          if (_hasActiveFilters)
            _FilterChip(
              label: 'Clear',
              isActive: false,
              isClear: true,
              onTap: _clearFilters,
            ),
        ],
      ),
    );
  }

  void _showStatusPicker() {
    _showOptionSheet(
      title: 'Filter by Status',
      options: ['all', 'active', 'disabled'],
      selected: _statusFilter,
      labelBuilder: (o) => o[0].toUpperCase() + o.substring(1),
      onSelect: (v) { setState(() => _statusFilter = v); _loadRestaurants(); },
    );
  }

  void _showSourcePicker() {
    _showOptionSheet(
      title: 'Filter by Source',
      options: ['all', 'admin', 'API', 'user-approved'],
      selected: _sourceFilter,
      labelBuilder: (o) => o == 'all' ? 'All' : o,
      onSelect: (v) { setState(() => _sourceFilter = v); _loadRestaurants(); },
    );
  }

  void _showCuisinePicker() {
    final selectedCuisines = Set<String>.from(_cuisineFilters);

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              color: AppColors.background,
              child: Column(
                children: [
                  Container(
                    color: AppColors.cardBackground,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setModalState(() => selectedCuisines.clear());
                          },
                          child: const Text('Clear', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        ),
                        const Text('Filter by Cuisine', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              _cuisineFilters = selectedCuisines.toList();
                            });
                            Navigator.pop(context);
                            _loadRestaurants();
                          },
                          child: const Text('Done', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 0.5, color: AppColors.divider),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cuisines.length,
                      itemBuilder: (context, index) {
                        final cuisine = _cuisines[index];
                        final isSelected = selectedCuisines.contains(cuisine.id);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setModalState(() {
                              if (isSelected) {
                                selectedCuisines.remove(cuisine.id);
                              } else {
                                selectedCuisines.add(cuisine.id);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cuisine.description, style: TextStyle(fontSize: 16, color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                                if (isSelected)
                                  const Icon(CupertinoIcons.checkmark_alt, color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showOptionSheet({
    required String title,
    required List<String> options,
    required String selected,
    required String Function(String) labelBuilder,
    required ValueChanged<String> onSelect,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(title),
        actions: options.map((o) {
          final isSelected = o == selected;
          return CupertinoActionSheetAction(
            onPressed: () {
              onSelect(o);
              Navigator.pop(context);
            },
            child: Text(
              labelBuilder(o),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return _tab == 0 ? _buildRestaurantsList() : _buildApprovalsList();
  }

  Widget _buildRestaurantsList() {
    if (_isLoading && _restaurants.isEmpty) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    if (_error != null && _restaurants.isEmpty) {
      return _ErrorState(message: _error!, onRetry: _loadRestaurants);
    }
    if (_restaurants.isEmpty) {
      return const _EmptyState(
        icon: CupertinoIcons.building_2_fill,
        message: 'No restaurants found',
        subtitle: 'Tap "Add" to create one.',
      );
    }

    final filtered = _filteredRestaurants;
    if (filtered.isEmpty) {
      return const _EmptyState(
        icon: CupertinoIcons.search,
        message: 'No matching restaurants',
        subtitle: 'Try adjusting your search or filters.',
      );
    }

    return CustomScrollView(
      controller: _restScrollCtrl,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => _loadRestaurants(refresh: true),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 0, bottom: 24),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) => Container(height: 0.5, color: AppColors.divider),
            itemBuilder: (_, i) => _RestaurantRow(
              restaurant: filtered[i],
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => ViewRestaurantScreen(restaurantId: filtered[i].restaurantId),
                  ),
                );
              },
            ),
          ),
        ),
        if (_isFetchingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CupertinoActivityIndicator(radius: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildApprovalsList() {
    if (_isLoadingApprovals && _approvals.isEmpty) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    if (_approvalsError != null && _approvals.isEmpty) {
      return _ErrorState(message: _approvalsError!, onRetry: _loadApprovals);
    }
    if (_approvals.isEmpty) {
      return const _EmptyState(
        icon: CupertinoIcons.doc_text,
        message: 'No pending approvals',
      );
    }

    return CustomScrollView(
      controller: _apprScrollCtrl,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => _loadApprovals(refresh: true),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 0, bottom: 24),
          sliver: SliverList.separated(
            itemCount: _approvals.length,
            separatorBuilder: (_, _) => Container(height: 0.5, color: AppColors.divider),
            itemBuilder: (_, i) => _ApprovalRow(
              approval: _approvals[i],
              onTap: () {
                // Future: Navigate to view approval detail screen
              },
            ),
          ),
        ),
        if (_isFetchingMoreApprovals)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CupertinoActivityIndicator(radius: 10),
            ),
          ),
      ],
    );
  }
}

// ── Animated underline tab bar ────────────────────────────────────────────────

class _SlideTabBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _SlideTabBar({
    required this.labels,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(labels.length, (i) {
            final selected = i == selectedIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10, top: 10),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      child: Text(labels[i]),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        // Sliding underline
        LayoutBuilder(builder: (ctx, constraints) {
          final tabWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              Container(height: 1, color: AppColors.divider),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                left: tabWidth * selectedIndex,
                child: Container(
                  width: tabWidth,
                  height: 2,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ── Header action widgets ────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _HeaderIconButton({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: AppColors.textSecondary),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(50),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: CupertinoColors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
          ],
        ),
      ),
    );
  }
}

// ── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isClear;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    this.isClear = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isClear
        ? AppColors.textLight.withAlpha(20)
        : isActive
            ? AppColors.primary.withAlpha(18)
            : AppColors.background;
    final Color fg = isClear
        ? AppColors.textSecondary
        : isActive
            ? AppColors.primary
            : AppColors.textSecondary;
    final Color border = isActive
        ? AppColors.primary.withAlpha(60)
        : AppColors.divider;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
            if (!isClear) ...[
              const SizedBox(width: 2),
              Icon(CupertinoIcons.chevron_down, size: 10, color: fg),
            ],
            if (isClear) ...[
              const SizedBox(width: 2),
              Icon(CupertinoIcons.xmark, size: 10, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Restaurant Row ───────────────────────────────────────────────────────────

class _RestaurantRow extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;

  const _RestaurantRow({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final coverUrl = restaurant.imageUrls.isNotEmpty ? restaurant.imageUrls.first : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(coverUrl, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Icon(CupertinoIcons.photo, size: 22, color: AppColors.textLight),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  if (restaurant.address != null)
                    Text(
                      restaurant.address!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (restaurant.mainCuisineId != null)
                        _MiniTag(label: restaurant.mainCuisineId!, color: const Color(0xFF007AFF)),
                      if (restaurant.source != null) ...[
                        const SizedBox(width: 6),
                        _MiniTag(label: restaurant.source!, color: const Color(0xFF34C759)),
                      ],
                      const SizedBox(width: 6),
                      _StatusBadge(isDisabled: restaurant.isDisabled),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

// ── Mini Tag ─────────────────────────────────────────────────────────────────

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isDisabled;
  const _StatusBadge({required this.isDisabled});

  @override
  Widget build(BuildContext context) {
    final color = isDisabled ? const Color(0xFFFF3B30) : const Color(0xFF34C759);
    final label = isDisabled ? 'Disabled' : 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(50), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  const _EmptyState({required this.icon, required this.message, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
          ],
        ],
      ),
    );
  }
}

// ── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Color(0xFFFF9500)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ── Approval Row ─────────────────────────────────────────────────────────────

class _ApprovalRow extends StatelessWidget {
  final RestaurantApprovalModel approval;
  final VoidCallback onTap;

  const _ApprovalRow({required this.approval, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: const Center(
                child: Icon(CupertinoIcons.doc_text, size: 22, color: AppColors.textLight),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    approval.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  if (approval.address != null)
                    Text(
                      approval.address!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (approval.source != null) ...[
                        _MiniTag(label: approval.source!, color: const Color(0xFF34C759)),
                        const SizedBox(width: 6),
                      ],
                      _MiniTag(label: 'Pending', color: const Color(0xFFFF9500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
