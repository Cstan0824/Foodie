import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';
import 'package:taste_spot/data/models/cuisine_model.dart';
import 'package:taste_spot/data/repositories/restaurant_repository.dart';
import 'package:taste_spot/data/models/restaurant_approval_model.dart';
import 'package:taste_spot/data/repositories/restaurant_approval_repository.dart';
import 'package:taste_spot/features/admin/restaurant_management/screens/view_restaurant_screen.dart';
import 'package:taste_spot/features/admin/restaurant_management/screens/add_edit_approve_restaurant.dart';

// ── Screen ───────────────────────────────────────────────────────────────────

class RestaurantManagementScreen extends StatefulWidget {
  const RestaurantManagementScreen({super.key});

  @override
  State<RestaurantManagementScreen> createState() =>
      _RestaurantManagementScreenState();
}

class _RestaurantManagementScreenState extends State<RestaurantManagementScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _tabAnim;
  final TextEditingController _restaurantSearchCtrl = TextEditingController();
  final TextEditingController _approvalSearchCtrl = TextEditingController();

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

  bool _isSwitchingTab = false;
  bool _isImportingFromApi = false;
  bool _stopImportAfterCurrentCity = false;
  int _importCompletedCities = 0;
  int _importTotalCities = 0;
  String? _importCurrentCity;
  final List<String> _importErrors = [];
  final _ApiImportSummary _importSummary = _ApiImportSummary();

  static const int _limit = 20;
  static const Map<String, List<String>> _citiesByState = {
    'Kuala Lumpur': ['Kuala Lumpur'],
    'Selangor': [
      'Petaling Jaya',
      'Shah Alam',
      'Subang Jaya',
      'Klang',
      'Ampang',
      'Kajang',
      'Puchong',
      'Cyberjaya',
      'Putrajaya',
      'Serdang',
    ],
    'Penang': ['George Town', 'Butterworth', 'Bayan Lepas', 'Bukit Mertajam'],
    'Johor': ['Johor Bahru', 'Iskandar Puteri', 'Batu Pahat', 'Muar', 'Kluang'],
    'Perak': ['Ipoh', 'Taiping', 'Teluk Intan', 'Kampar'],
    'Melaka': ['Melaka City', 'Ayer Keroh', 'Alor Gajah'],
    'Kedah': ['Alor Setar', 'Sungai Petani', 'Langkawi', 'Kulim'],
    'Pahang': ['Kuantan', 'Temerloh', 'Bentong', 'Cameron Highlands'],
    'Kelantan': ['Kota Bharu', 'Pasir Mas', 'Tanah Merah'],
    'Terengganu': ['Kuala Terengganu', 'Kemaman', 'Dungun'],
    'Negeri Sembilan': ['Seremban', 'Port Dickson', 'Nilai'],
    'Perlis': ['Kangar', 'Arau'],
    'Sabah': ['Kota Kinabalu', 'Sandakan', 'Tawau'],
    'Sarawak': ['Kuching', 'Miri', 'Sibu', 'Bintulu'],
    'Putrajaya': ['Putrajaya'],
    'Labuan': ['Labuan'],
  };

  // Search & filter state
  String _searchQuery = '';
  String _statusFilter = 'all'; // all | active | disabled
  String _sourceFilter = 'all'; // all | admin | API
  List<String> _cuisineFilters = [];
  String _sort = 'newest'; // newest | oldest | a-z | z-a

  String _approvalSearchQuery = '';
  String _approvalStatusFilter = 'all'; // all | pending | accepted | rejected
  String _approvalSort = 'newest'; // newest | oldest | name_az | name_za

  final _repo = RestaurantRepository.instance;
  final _approvalRepo = RestaurantApprovalRepository.instance;

  List<String> get _apiImportCities =>
      _citiesByState.values.expand((cities) => cities).toList();
  Future<void> _showImportFromApiConfirmation() async {
    if (_isImportingFromApi) return;

    final shouldProceed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Import restaurants from API?'),
        content: Text(
          'This will import up to 10 restaurants for each supported city in Malaysia. '
          'New restaurants will be saved directly, while possible duplicates based on address or location will be sent to the approval list.\n\n'
          'Restaurant and approval images will be copied into Supabase Storage.\n\n'
          'This action may use Google Places API quota.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      await _importAllCitiesFromApi();
    }
  }

  Future<void> _importAllCitiesFromApi() async {
    final cities = _apiImportCities;

    setState(() {
      _isImportingFromApi = true;
      _stopImportAfterCurrentCity = false;
      _importCompletedCities = 0;
      _importTotalCities = cities.length;
      _importCurrentCity = null;
      _importErrors.clear();
      _importSummary.reset();
    });

    for (final city in cities) {
      if (_stopImportAfterCurrentCity) break;

      if (!mounted) return;
      setState(() => _importCurrentCity = city);

      try {
        final response = await Supabase.instance.client.functions.invoke(
          'import-google-places-restaurants',
          body: {
            'city': city,
            'limit': 10,
            'importPhoto': true,
          },
        );

        final data = response.data;
        if (data is Map) {
          _importSummary.addFromMap(data);
        } else {
          _importErrors.add('$city: Unexpected response format');
        }
      } catch (e) {
        _importErrors.add('$city: $e');
      }

      if (!mounted) return;
      setState(() => _importCompletedCities++);

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!mounted) return;

    setState(() {
      _isImportingFromApi = false;
      _importCurrentCity = null;
    });

    await _loadCuisines();
    await _loadRestaurants(refresh: true);
    await _loadApprovals(refresh: true);

    if (!mounted) return;
    await _showImportCompletedDialog();
  }

  Future<void> _showImportCompletedDialog() async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Import completed'),
        content: Text(
          'Cities processed: $_importCompletedCities / $_importTotalCities\n'
          'Found: ${_importSummary.found}\n'
          'Inserted: ${_importSummary.inserted}\n'
          'Updated: ${_importSummary.updated}\n'
          'Sent to approval: ${_importSummary.sentToApproval}\n'
          'Approval duplicates skipped: ${_importSummary.approvalDuplicateSkipped}\n'
          'Restaurant images: ${_importSummary.restaurantPhotoInserted}\n'
          'Approval images: ${_importSummary.approvalPhotoInserted}\n'
          'Cuisines created: ${_importSummary.cuisinesCreated}\n'
          'Failed: ${_importSummary.failedCount + _importErrors.length}',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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
    _restaurantSearchCtrl.dispose();
    _approvalSearchCtrl.dispose();
    super.dispose();
  }

  void _onRestScroll() {
    if (_restScrollCtrl.position.pixels >=
        _restScrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreRestaurants();
    }
  }

  void _onApprScroll() {
    if (_apprScrollCtrl.position.pixels >=
        _apprScrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreApprovals();
    }
  }

  void _switchTab(int index) async {
    if (index == _tab) return;

    final currentTab = index;
    setState(() {
      _tab = index;
      _isSwitchingTab = true;
    });

    if (index == 1) {
      _tabAnim.forward();
      await _loadApprovals(refresh: true);
    } else {
      _tabAnim.reverse();
      await _loadRestaurants(refresh: true);
    }

    if (mounted && _tab == currentTab) {
      setState(() {
        _isSwitchingTab = false;
      });
    }
  }

  int? _approvalStatusCodeFromFilter(String filter) {
    switch (filter) {
      case 'pending':
        return 0;
      case 'accepted':
        return 1;
      case 'rejected':
        return 2;
      default:
        return null;
    }
  }

  void _sortApprovalList(List<RestaurantApprovalModel> items) {
    switch (_approvalSort) {
      case 'oldest':
        items.sort((a, b) {
          final da = a.detectedAt;
          final db = b.detectedAt;
          if (da == null && db == null) return 0;
          if (da == null) return -1;
          if (db == null) return 1;
          return da.compareTo(db);
        });
        break;
      case 'a-z':
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'z-a':
        items.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case 'newest':
      default:
        items.sort((a, b) {
          final da = a.detectedAt;
          final db = b.detectedAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
        break;
    }
  }

  Future<void> _loadApprovals({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _approvalsError = null;
        _hasMoreApprovals = true;
      });
    }
    setState(() {
      _isLoadingApprovals = true;
      _approvalsError = null;
    });
    try {
      final approvals = await _approvalRepo.fetchApprovals(
        statusFilter: _approvalStatusCodeFromFilter(_approvalStatusFilter),
        searchQuery: _approvalSearchQuery.isEmpty ? null : _approvalSearchQuery,
        limit: _limit,
        offset: 0,
      );
      _sortApprovalList(approvals);
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
    if (_isFetchingMoreApprovals || !_hasMoreApprovals || _isLoadingApprovals) {
      return;
    }
    setState(() => _isFetchingMoreApprovals = true);
    try {
      final more = await _approvalRepo.fetchApprovals(
        statusFilter: _approvalStatusCodeFromFilter(_approvalStatusFilter),
        searchQuery: _approvalSearchQuery.isEmpty ? null : _approvalSearchQuery,
        limit: _limit,
        offset: _approvals.length,
      );
      if (!mounted) return;
      setState(() {
        _approvals.addAll(more);
        _sortApprovalList(_approvals);
        _hasMoreApprovals = more.length == _limit;
        _isFetchingMoreApprovals = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isFetchingMoreApprovals = false);
    }
  }

  void _sortRestaurantList(List<RestaurantModel> items) {
    switch (_sort) {
      case 'oldest':
        items.sort((a, b) {
          final da = a.createdAt;
          final db = b.createdAt;
          if (da == null && db == null) return 0;
          if (da == null) return -1;
          if (db == null) return 1;
          return da.compareTo(db);
        });
        break;
      case 'a-z':
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'z-a':
        items.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case 'newest':
      default:
        items.sort((a, b) {
          final da = a.createdAt;
          final db = b.createdAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
        break;
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
      setState(() {
        _error = null;
        _hasMoreRestaurants = true;
      });
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final restaurants = await _repo.fetchAllRestaurants(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        isDisabled: _statusFilter == 'all' ? null : _statusFilter == 'disabled',
        source: _sourceFilter == 'all' ? null : _sourceFilter,
        cuisineIds: _cuisineFilters.isEmpty ? null : _cuisineFilters,
        limit: _limit,
        offset: 0,
      );
      _sortRestaurantList(restaurants);
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
        _sortRestaurantList(_restaurants);
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
    _restaurantSearchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = 'all';
      _sourceFilter = 'all';
      _cuisineFilters.clear();
      _sort = 'newest';
    });
    _loadRestaurants(refresh: true);
  }

  bool get _hasActiveFilters =>
      _statusFilter != 'all' ||
      _sourceFilter != 'all' ||
      _cuisineFilters.isNotEmpty ||
      _sort != 'newest';

  bool get _hasActiveApprovalFilters =>
      _approvalSearchQuery.trim().isNotEmpty ||
      _approvalStatusFilter != 'all' ||
      _approvalSort != 'newest';

  void _clearApprovalFilters() {
    _approvalSearchCtrl.clear();
    setState(() {
      _approvalSearchQuery = '';
      _approvalStatusFilter = 'all';
      _approvalSort = 'newest';
    });
    _loadApprovals(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // ── Header ──
            _buildHeader(context),
            // ── Content ──
            Expanded(child: _buildBody()),
          ],
        ),
        if (_tab == 0)
          Positioned(
            right: 16,
            bottom: 30,
            child: _FloatingAddButton(
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  CupertinoPageRoute(
                    builder: (_) => const AddEditApproveRestaurantScreen(),
                  ),
                );
                if (changed == true && mounted) {
                  _loadRestaurants(refresh: true);
                }
              },
            ),
          ),
        if (_isImportingFromApi)
          Positioned.fill(
            child: _ApiImportProgressOverlay(
              currentCity: _importCurrentCity,
              completedCities: _importCompletedCities,
              totalCities: _importTotalCities,
              summary: _importSummary,
              errorCount: _importErrors.length,
              onStopAfterCurrentCity: () {
                setState(() => _stopImportAfterCurrentCity = true);
              },
              isStopping: _stopImportAfterCurrentCity,
            ),
          ),
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
              left: 16,
              right: 16,
              bottom: 4,
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
                if (_tab == 0)
                  _HeaderIconButton(
                    icon: CupertinoIcons.cloud_download,
                    onTap: _showImportFromApiConfirmation,
                    tooltip: 'Import from API',
                  ),
              ],
            ),
          ),

          // ── Animated underline tab bar ──
          _PillTabBar(
            labels: ['List', 'Approval'],
            counts: [_restaurants.length, _approvals.length],
            selectedIndex: _tab,
            onTap: _switchTab,
          ),
          // ── Search bar ──
          if (_tab == 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoSearchTextField(
                      controller: _restaurantSearchCtrl,
                      placeholder: 'Search by name or address',
                      onChanged: (v) {
                        setState(() => _searchQuery = v);
                        _loadRestaurants();
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ClearFiltersIconButton(
                    isActive:
                        _hasActiveFilters || _searchQuery.trim().isNotEmpty,
                    onTap: _clearFilters,
                  ),
                ],
              ),
            ),
            // ── Filters ──
            _buildFilterBar(),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoSearchTextField(
                      controller: _approvalSearchCtrl,
                      placeholder: 'Search by name or address',
                      onChanged: (v) {
                        setState(() => _approvalSearchQuery = v);
                        _loadApprovals();
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ClearFiltersIconButton(
                    isActive: _hasActiveApprovalFilters,
                    onTap: _clearApprovalFilters,
                  ),
                ],
              ),
            ),
            _buildApprovalFilterBar(),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FilterChip(
                  label: 'Status: ${_statusFilter.toUpperCase()}',
                  isActive: _statusFilter != 'all',
                  onTap: () => _showStatusPicker(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterChip(
                  label: 'Source: ${_sourceFilter.toUpperCase()}',
                  isActive: _sourceFilter != 'all',
                  onTap: () => _showSourcePicker(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FilterChip(
                  label: 'Sort: ${_sort.toUpperCase()}',
                  isActive: _sort != 'newest',
                  onTap: _showSortPicker,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterChip(
                  label: _cuisineFilters.isEmpty
                      ? 'Cuisine'
                      : _cuisineFilters.length == 1
                      ? _cuisines
                            .firstWhere(
                              (c) => c.id == _cuisineFilters.first,
                              orElse: () => _cuisines.first,
                            )
                            .description
                      : '${_cuisineFilters.length} Cuisines',
                  isActive: _cuisineFilters.isNotEmpty,
                  onTap: () => _showCuisinePicker(),
                ),
              ),
            ],
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
      onSelect: (v) {
        setState(() => _statusFilter = v);
        _loadRestaurants();
      },
    );
  }

  void _showSourcePicker() {
    _showOptionSheet(
      title: 'Filter by Source',
      options: ['all', 'ADMIN', 'API'],
      selected: _sourceFilter,
      labelBuilder: (o) => o == 'all' ? 'All' : o,
      onSelect: (v) {
        setState(() => _sourceFilter = v);
        _loadRestaurants();
      },
    );
  }

  void _showSortPicker() {
    const labels = {
      'newest': 'Newest first',
      'oldest': 'Oldest first',
      'a-z': 'A-Z',
      'z-a': 'Z-A',
    };

    _showOptionSheet(
      title: 'Sort Restaurants',
      options: const ['newest', 'oldest', 'a-z', 'z-a'],
      selected: _sort,
      labelBuilder: (o) => labels[o] ?? o,
      onSelect: (v) {
        setState(() => _sort = v);
        _loadRestaurants(refresh: true);
      },
    );
  }

  Widget _buildApprovalFilterBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10, left: 16, right: 16),
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              label: 'Status: ${_approvalStatusFilter.toUpperCase()}',
              isActive: _approvalStatusFilter != 'all',
              onTap: _showApprovalStatusPicker,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChip(
              label: 'Sort: ${_approvalSort.toUpperCase()}',
              isActive: _approvalSort != 'newest',
              onTap: _showApprovalSortPicker,
            ),
          ),
        ],
      ),
    );
  }

  void _showApprovalStatusPicker() {
    _showOptionSheet(
      title: 'Approval Status',
      options: ['all', 'pending', 'accepted', 'rejected'],
      selected: _approvalStatusFilter,
      labelBuilder: (o) => o[0].toUpperCase() + o.substring(1),
      onSelect: (v) {
        setState(() => _approvalStatusFilter = v);
        _loadApprovals();
      },
    );
  }

  void _showApprovalSortPicker() {
    const labels = {
      'newest': 'Newest first',
      'oldest': 'Oldest first',
      'a-z': 'A-Z',
      'z-a': 'Z-A',
    };

    _showOptionSheet(
      title: 'Sort Approvals',
      options: const ['newest', 'oldest', 'a-z', 'z-a'],
      selected: _approvalSort,
      labelBuilder: (o) => labels[o] ?? o,
      onSelect: (v) {
        setState(() => _approvalSort = v);
        _loadApprovals(refresh: true);
      },
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setModalState(() => selectedCuisines.clear());
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Text(
                          'Filter by Cuisine',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              _cuisineFilters = selectedCuisines.toList();
                            });
                            Navigator.pop(context);
                            _loadRestaurants();
                          },
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
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
                        final isSelected = selectedCuisines.contains(
                          cuisine.id,
                        );
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.divider,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  cuisine.description,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    CupertinoIcons.checkmark_alt,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
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
    if (_isSwitchingTab) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
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
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => _loadRestaurants(refresh: true),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 0, bottom: 24),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) =>
                Container(height: 0.5, color: AppColors.divider),
            itemBuilder: (_, i) => _RestaurantRow(
              restaurant: filtered[i],
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => ViewRestaurantScreen(
                      restaurantId: filtered[i].restaurantId,
                    ),
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
      if (_hasActiveApprovalFilters) {
        return const _EmptyState(
          icon: CupertinoIcons.search,
          message: 'No matching approvals',
          subtitle: 'Try adjusting search or filters.',
        );
      }
      return const _EmptyState(
        icon: CupertinoIcons.doc_text,
        message: 'No approvals yet',
        subtitle: 'Pending, accepted, and rejected items will appear here.',
      );
    }

    return CustomScrollView(
      controller: _apprScrollCtrl,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => _loadApprovals(refresh: true),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 0, bottom: 24),
          sliver: SliverList.separated(
            itemCount: _approvals.length,
            separatorBuilder: (_, _) =>
                Container(height: 0.5, color: AppColors.divider),
            itemBuilder: (_, i) => _ApprovalRow(
              approval: _approvals[i],
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  CupertinoPageRoute(
                    builder: (_) => AddEditApproveRestaurantScreen(
                      approvalId: _approvals[i].approvalId,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  _loadApprovals(refresh: true);
                  _loadRestaurants(refresh: true);
                }
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

// ── Pill tab bar ─────────────────────────────────────────────────────────────

class _PillTabBar extends StatelessWidget {
  final List<String> labels;
  final List<int> counts;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _PillTabBar({
    required this.labels,
    required this.counts,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                left: selectedIndex * tabWidth + 2,
                top: 2,
                width: tabWidth - 4,
                height: constraints.maxHeight - 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withAlpha(18),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(labels.length, (i) {
                  final isSelected = i == selectedIndex;
                  final count = i < counts.length ? counts[i] : 0;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              child: Text(labels[i]),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 5),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withAlpha(20)
                                      : AppColors.textLight.withAlpha(60),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
    );
  }
}

// ── Header action widgets ────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: AppColors.textSecondary),
      ),
    );
  }
}

class _FloatingAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FloatingAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withAlpha(30),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(CupertinoIcons.add, size: 24, color: Color(0xFFFF3B30)),
        ),
      ),
    );
  }
}

// ── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isActive
        ? AppColors.primary.withAlpha(18)
        : AppColors.background;
    final Color fg = isActive ? AppColors.primary : AppColors.textSecondary;
    final Color border = isActive
        ? AppColors.primary.withAlpha(60)
        : AppColors.divider;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 2),
              Icon(CupertinoIcons.chevron_down, size: 10, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearFiltersIconButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _ClearFiltersIconButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withAlpha(18)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withAlpha(60)
                : AppColors.divider,
            width: 0.5,
          ),
        ),
        child: Icon(
          CupertinoIcons.trash_slash,
          size: 17,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
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
    final coverUrl = restaurant.imageUrls.isNotEmpty
        ? restaurant.imageUrls.first
        : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
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
                      child: Icon(
                        CupertinoIcons.photo,
                        size: 22,
                        color: AppColors.textLight,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  if (restaurant.address != null)
                    Text(
                      restaurant.address!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (restaurant.mainCuisineId != null)
                        _MiniTag(
                          label: restaurant.mainCuisineId!,
                          color: const Color(0xFF007AFF),
                        ),
                      if (restaurant.source != null) ...[
                        const SizedBox(width: 6),
                        _MiniTag(
                          label: restaurant.source!,
                          color: const Color(0xFF34C759),
                        ),
                      ],
                      const SizedBox(width: 6),
                      _StatusBadge(isDisabled: restaurant.isDisabled),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.textLight,
            ),
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
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
    final color = isDisabled
        ? const Color(0xFFFF3B30)
        : const Color(0xFF34C759);
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
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
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
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
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
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 48,
            color: Color(0xFFFF9500),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
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

  String _statusLabel(int status) {
    switch (status) {
      case 1:
        return 'Accepted';
      case 2:
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return const Color(0xFF34C759);
      case 2:
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFFFF9500);
    }
  }

  String _formatDetectedAt(DateTime? value) {
    if (value == null) return 'Unknown date';
    final local = value.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = approval.imageUrl?.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: thumbUrl != null && thumbUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            CupertinoIcons.doc_text,
                            size: 22,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        CupertinoIcons.doc_text,
                        size: 22,
                        color: AppColors.textLight,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    approval.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  if (approval.address != null)
                    Text(
                      approval.address!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDetectedAt(approval.detectedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (approval.source != null) ...[
                        _MiniTag(
                          label: approval.source!,
                          color: const Color(0xFF34C759),
                        ),
                        const SizedBox(width: 6),
                      ],
                      _MiniTag(
                        label: _statusLabel(approval.status),
                        color: _statusColor(approval.status),
                      ),
                      if (approval.currRestaurantId != null &&
                          approval.currRestaurantId!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _MiniTag(
                          label: 'Replacement',
                          color: const Color(0xFF5856D6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}


class _ApiImportSummary {
  int found = 0;
  int inserted = 0;
  int updated = 0;
  int sentToApproval = 0;
  int approvalDuplicateSkipped = 0;
  int skipped = 0;
  int restaurantPhotoInserted = 0;
  int approvalPhotoInserted = 0;
  int cuisinesCreated = 0;
  int cuisinesReused = 0;
  int failedCount = 0;

  void reset() {
    found = 0;
    inserted = 0;
    updated = 0;
    sentToApproval = 0;
    approvalDuplicateSkipped = 0;
    skipped = 0;
    restaurantPhotoInserted = 0;
    approvalPhotoInserted = 0;
    cuisinesCreated = 0;
    cuisinesReused = 0;
    failedCount = 0;
  }

  void addFromMap(Map data) {
    found += _toInt(data['found']);
    inserted += _toInt(data['inserted']);
    updated += _toInt(data['updated']);
    sentToApproval += _toInt(data['sentToApproval']);
    approvalDuplicateSkipped += _toInt(data['approvalDuplicateSkipped']);
    skipped += _toInt(data['skipped']);
    restaurantPhotoInserted += _toInt(data['restaurantPhotoInserted']);
    approvalPhotoInserted += _toInt(data['approvalPhotoInserted']);
    cuisinesCreated += _toInt(data['cuisinesCreated']);
    cuisinesReused += _toInt(data['cuisinesReused']);
    failedCount += _toInt(data['failedCount']);
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class _ApiImportProgressOverlay extends StatelessWidget {
  final String? currentCity;
  final int completedCities;
  final int totalCities;
  final _ApiImportSummary summary;
  final int errorCount;
  final VoidCallback onStopAfterCurrentCity;
  final bool isStopping;

  const _ApiImportProgressOverlay({
    required this.currentCity,
    required this.completedCities,
    required this.totalCities,
    required this.summary,
    required this.errorCount,
    required this.onStopAfterCurrentCity,
    required this.isStopping,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCities == 0 ? 0.0 : completedCities / totalCities;

    return Container(
      color: const Color(0xFF000000).withAlpha(90),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width - 40,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CupertinoActivityIndicator(radius: 10),
                  SizedBox(width: 10),
                  Text(
                    'Importing restaurants...',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Current city: ${currentCity ?? '-'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  height: 7,
                  color: AppColors.surface,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$completedCities / $totalCities cities completed',
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 14),
              _ImportStatLine(label: 'Found', value: summary.found),
              _ImportStatLine(label: 'Inserted', value: summary.inserted),
              _ImportStatLine(label: 'Updated', value: summary.updated),
              _ImportStatLine(label: 'Sent to approval', value: summary.sentToApproval),
              _ImportStatLine(label: 'Restaurant images', value: summary.restaurantPhotoInserted),
              _ImportStatLine(label: 'Approval images', value: summary.approvalPhotoInserted),
              _ImportStatLine(label: 'Errors', value: summary.failedCount + errorCount),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: isStopping ? AppColors.surface : const Color(0xFFFF9500),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: isStopping ? null : onStopAfterCurrentCity,
                  child: Text(
                    isStopping ? 'Stopping after current city...' : 'Stop after current city',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isStopping ? AppColors.textSecondary : CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportStatLine extends StatelessWidget {
  final String label;
  final int value;

  const _ImportStatLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}