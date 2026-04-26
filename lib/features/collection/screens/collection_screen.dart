import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors; 
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/models/collection_model.dart';
import 'package:taste_spot/data/repositories/collection_repository.dart';
import 'package:taste_spot/features/collection/screens/collection_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => CollectionScreenState();
}

class CollectionScreenState extends State<CollectionScreen> {
  final CollectionRepository _collectionRepository = CollectionRepository(
    Supabase.instance.client,
  );
  List<Collection> _collections = [];
  List<Collection> _sharedCollections = [];
  bool _isLoading = true;
  String? _error;
  
  // 0: All, 1: Restaurants, 2: Posts
  int _selectedCategory = 0; 
  bool _isMenuOpen = false;
  
  // 0: My, 1: Shared
  int _selectedTab = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text));
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void refreshCollections() => _loadAllData();

  Future<void> _loadAllData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() { _error = "User not logged in"; _isLoading = false; });
      return;
    }
    
    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _collectionRepository.getUserCollections(userId),
        _collectionRepository.getSharedCollections(userId),
      ]);
      
      if (mounted) {
        setState(() {
          _collections = results[0];
          _sharedCollections = results[1];
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<Collection> get _filteredCollections {
    var list = _selectedTab == 0 ? _collections : _sharedCollections;
    
    if (_selectedCategory == 1) {
      list = list.where((c) => c.collectionType == 'RESTAURANT').toList();
    } else if (_selectedCategory == 2) {
      list = list.where((c) => c.collectionType == 'POST').toList();
    }
    
    if (_searchQuery.isEmpty) return list;
    final lowerQuery = _searchQuery.toLowerCase();
    return list.where((c) => c.name.toLowerCase().contains(lowerQuery)).toList();
  }

  String get _categoryLabel {
    switch (_selectedCategory) {
      case 1: return 'Restaurants';
      case 2: return 'Posts';
      default: return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withAlpha(240),
        border: null,
        middle: const Text('Collections', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0, fontSize: 22, color: AppColors.textPrimary)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showCreateCollectionSheet(context),
          child: const Icon(CupertinoIcons.plus_circle_fill, color: AppColors.primary, size: 28),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTabToggle(),
                _buildSearchBar(),
                Expanded(child: _buildContent()),
              ],
            ),
            
            // Custom Dropdown Overlay
            if (_isMenuOpen)
              GestureDetector(
                onTap: () => setState(() => _isMenuOpen = false),
                child: Container(
                  color: Colors.black.withAlpha(20),
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            
            _buildCustomDropdownMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _selectedTab,
        backgroundColor: AppColors.surface,
        thumbColor: CupertinoColors.white,
        padding: const EdgeInsets.all(4),
        children: {
          0: _buildTabItem('My Items', 0),
          1: _buildTabItem('Shared', 1),
        },
        onValueChanged: (val) {
          if (val != null) setState(() => _selectedTab = val);
        },
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    final isSelected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider.withAlpha(50), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.search, size: 18, color: AppColors.textLight),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      placeholder: 'Search collections...',
                      placeholderStyle: const TextStyle(color: AppColors.textLight, fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: null,
                      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      clearButtonMode: OverlayVisibilityMode.editing,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _isMenuOpen ? AppColors.textPrimary : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isMenuOpen ? [
                  BoxShadow(color: AppColors.textPrimary.withAlpha(40), blurRadius: 10, offset: const Offset(0, 4))
                ] : [],
              ),
              child: Row(
                children: [
                  Text(
                    _categoryLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _isMenuOpen ? CupertinoColors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isMenuOpen ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                    size: 14,
                    color: _isMenuOpen ? CupertinoColors.white : AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDropdownMenu() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
      top: _isMenuOpen ? 120 : 100,
      right: 20,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isMenuOpen ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_isMenuOpen,
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 30, offset: const Offset(0, 15)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuOption('All Items', 0, CupertinoIcons.square_grid_2x2_fill),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Divider(height: 1, color: AppColors.divider)),
                _buildMenuOption('Restaurants', 1, CupertinoIcons.house_fill),
                _buildMenuOption('Posts', 2, CupertinoIcons.doc_text_fill),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(String label, int index, IconData icon) {
    final isSelected = _selectedCategory == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = index;
          _isMenuOpen = false;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(CupertinoIcons.checkmark_alt, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _collections.isEmpty && _sharedCollections.isEmpty) {
      return const _CollectionSkeleton();
    }
    if (_error != null && _collections.isEmpty && _sharedCollections.isEmpty) {
      return _buildErrorState();
    }

    final items = _filteredCollections;
    
    if (items.isEmpty) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _loadAllData),
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: Icon(
                      _searchQuery.isEmpty ? CupertinoIcons.folder_badge_plus : CupertinoIcons.search, 
                      size: 64, color: AppColors.textLight.withAlpha(100)
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _searchQuery.isEmpty ? 'No collections here yet' : 'No matches for "$_searchQuery"',
                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isEmpty 
                      ? 'Create your first one to get started!' 
                      : 'Try adjusting your search query',
                    style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _loadAllData),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 32,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildCollectionCard(items[index]),
              childCount: items.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildCollectionCard(Collection collection) {
    final isOwnTab = _selectedTab == 0;
    final cardColor = AppColors.background; 
    final images = collection.latestItemImages;
    
    return GestureDetector(
      onTap: () async {
        if (_isMenuOpen) {
          setState(() => _isMenuOpen = false);
          return;
        }
        final result = await Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => CollectionDetailScreen(collection: collection)),
        );
        if (result == true) _loadAllData();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Folder Back Stack Effect
                Positioned(
                  top: -8, left: 14, right: 14, bottom: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor.withAlpha(150),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  top: -4, left: 7, right: 7, bottom: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor.withAlpha(200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                // Main Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: AppColors.divider.withAlpha(60), width: 1),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (images.isEmpty) 
                        Center(
                          child: Icon(
                            collection.collectionType == 'RESTAURANT' 
                                ? CupertinoIcons.house_fill 
                                : CupertinoIcons.square_favorites_fill,
                            size: 44, 
                            color: AppColors.textPrimary.withAlpha(180),
                          ),
                        )
                      else ...[
                        // Second image (bottom/back card)
                        if (images.length > 1)
                          Positioned(
                            top: 4, right: 6,
                            bottom: 12, left: 16,
                            child: Transform.rotate(
                              angle: 0.04,
                              child: _buildItemPreview(images[1]),
                            ),
                          ),
                        // First image (top/front card)
                        Positioned(
                          top: images.length > 1 ? -4 : 0, 
                          left: images.length > 1 ? -12 : 0,
                          bottom: images.length > 1 ? 16 : 0, 
                          right: images.length > 1 ? 24 : 0,
                          child: Transform.rotate(
                            angle: images.length > 1 ? -0.02 : 0.0,
                            child: _buildItemPreview(images[0]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Indicators
                if (!collection.isPublic)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.black.withAlpha(140), shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.lock_fill, size: 10, color: CupertinoColors.white),
                    ),
                  ),
                if (collection.isDefault && isOwnTab)
                  Positioned(
                    top: 12, left: 6,
                    child: Transform.rotate(
                      angle: images.length > 1 ? -0.02 : 0.0, // Match the front card rotation
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary, 
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Text('DEFAULT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            collection.name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4),
          ),
          const SizedBox(height: 4),
          if (!isOwnTab && collection.owner != null)
            Row(
              children: [
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.surface, 
                    shape: BoxShape.circle, 
                    border: Border.all(color: AppColors.divider, width: 0.5)
                  ),
                  child: ClipOval(
                    child: (collection.owner!.imageUrl != null && collection.owner!.imageUrl!.isNotEmpty)
                        ? Image.network(collection.owner!.imageUrl!, fit: BoxFit.cover, 
                            errorBuilder: (_, _, _) => const Icon(CupertinoIcons.person_fill, size: 10, color: AppColors.textLight))
                        : const Icon(CupertinoIcons.person_fill, size: 10, color: AppColors.textLight),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    collection.owner!.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          else
            Text(
              collection.collectionType == 'RESTAURANT' ? 'Restaurant List' : 'Post Gallery',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  Widget _buildItemPreview(String url) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 12, offset: const Offset(0, 6)),
        ],
        border: Border.all(color: CupertinoColors.white, width: 2.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.5),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 48, color: CupertinoColors.systemRed),
            const SizedBox(height: 20),
            const Text('Connection Problem', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text(_error ?? 'Unable to fetch your collections', 
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),
            CupertinoButton(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              onPressed: _loadAllData, 
              child: const Text('Try Reloading', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCollectionSheet(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final FocusNode nameFocusNode = FocusNode();
    String type = 'POST';
    bool isCreating = false;
    String? nameError;

    showCupertinoModalPopup(
      context: context,
      barrierColor: Colors.black.withAlpha(100),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 40,
            top: 12, left: 24, right: 24,
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
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2.5)),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Create Collection', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 24),
              const Text('COLLECTION NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              
              // Animated container for border and shadow effect
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: nameError != null 
                        ? CupertinoColors.destructiveRed 
                        : (nameFocusNode.hasFocus ? AppColors.primary : AppColors.divider.withAlpha(50)),
                    width: nameError != null || nameFocusNode.hasFocus ? 1.5 : 1,
                  ),
                ),
                child: CupertinoTextField(
                  controller: nameController,
                  focusNode: nameFocusNode,
                  placeholder: 'e.g. Weekend Brunch Plans',
                  autofocus: true,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: null,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  onChanged: (val) {
                    if (nameError != null) setSheetState(() => nameError = null);
                  },
                ),
              ),
              
              if (nameError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    nameError!,
                    style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),

              const SizedBox(height: 28),
              const Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TypeOption(
                    icon: CupertinoIcons.doc_text_fill,
                    label: 'Posts',
                    isSelected: type == 'POST',
                    onTap: () => setSheetState(() => type = 'POST'),
                  ),
                  const SizedBox(width: 16),
                  _TypeOption(
                    icon: CupertinoIcons.house_fill,
                    label: 'Places',
                    isSelected: type == 'RESTAURANT',
                    onTap: () => setSheetState(() => type = 'RESTAURANT'),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: isCreating ? null : () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    setSheetState(() => nameError = 'Please enter a collection name');
                    nameFocusNode.requestFocus();
                    return;
                  }
                  
                  setSheetState(() => isCreating = true);
                  try {
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user != null) {
                      await _collectionRepository.createCollection(
                        userId: user.id, 
                        name: name, 
                        collectionType: type,
                        isPublic: false, // Default to false as user choice is removed
                      );
                      if (context.mounted) { Navigator.pop(context); _loadAllData(); }
                    }
                  } catch (e) {
                    setSheetState(() {
                      isCreating = false;
                      nameError = 'Failed to create. Please try again.';
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: isCreating 
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text('Create Collection', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeOption({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected ? [
              BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 12, offset: const Offset(0, 6))
            ] : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? CupertinoColors.white : AppColors.textSecondary, size: 28),
              const SizedBox(height: 10),
              Text(label, style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w800, 
                color: isSelected ? CupertinoColors.white : AppColors.textSecondary,
                letterSpacing: 0.2
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionSkeleton extends StatelessWidget {
  const _CollectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 20, mainAxisSpacing: 28, childAspectRatio: 0.82,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Skeleton(borderRadius: 18)),
          SizedBox(height: 14),
          Skeleton(width: 120, height: 18, borderRadius: 4),
          SizedBox(height: 6),
          Skeleton(width: 80, height: 14, borderRadius: 4),
        ],
      ),
    );
  }
}

class Divider extends StatelessWidget {
  final double height;
  final Color color;

  const Divider({super.key, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color,
    );
  }
}
