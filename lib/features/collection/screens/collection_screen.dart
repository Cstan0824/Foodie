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
  bool _isLoading = true;
  String? _error;
  
  // 0: All, 1: Restaurants, 2: Posts
  int _selectedCategory = 0; 
  bool _isMenuOpen = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text));
    _loadCollections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void refreshCollections() => _loadCollections();

  Future<void> _loadCollections() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000001';
    if (mounted) setState(() => _isLoading = true);

    try {
      final collections = await _collectionRepository.getUserCollections(userId);
      if (mounted) setState(() { _collections = collections; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<Collection> get _filteredCollections {
    var list = _collections;
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
        backgroundColor: CupertinoColors.white,
        border: null,
        middle: const Text('Collections', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8, fontSize: 18)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showCreateCollectionSheet(context),
          child: const Icon(CupertinoIcons.add, color: AppColors.textPrimary, size: 24),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.search, size: 20, color: AppColors.textLight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      placeholder: 'Search collections...',
                      placeholderStyle: const TextStyle(color: AppColors.textLight, fontSize: 15),
                      decoration: null,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
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
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _isMenuOpen ? AppColors.textPrimary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedCategory != 0 && !_isMenuOpen ? AppColors.primary.withAlpha(100) : Colors.transparent, 
                  width: 1.5
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _categoryLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isMenuOpen 
                        ? CupertinoColors.white 
                        : (_selectedCategory != 0 ? AppColors.primary : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isMenuOpen ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                    size: 14,
                    color: _isMenuOpen 
                        ? CupertinoColors.white 
                        : (_selectedCategory != 0 ? AppColors.primary : AppColors.textLight),
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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      top: _isMenuOpen ? 60 : 40,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isMenuOpen ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_isMenuOpen,
          child: Container(
            width: 180,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuOption('All', 0, CupertinoIcons.square_grid_2x2),
                _buildMenuOption('Restaurants', 1, CupertinoIcons.house),
                _buildMenuOption('Posts', 2, CupertinoIcons.doc_text),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              size: 18, 
              color: isSelected ? AppColors.primary : AppColors.textSecondary
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(CupertinoIcons.checkmark_alt, size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const _CollectionSkeleton();
    if (_error != null) return _buildErrorState();

    final items = _filteredCollections;
    
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.folder_badge_plus, size: 64, color: AppColors.surface),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No collections matching this type' : 'No results found',
              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildCollectionCard(items[index]),
    );
  }

  Widget _buildCollectionCard(Collection collection) {
    return GestureDetector(
      onTap: () async {
        if (_isMenuOpen) {
          setState(() => _isMenuOpen = false);
          return;
        }
        final result = await Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => CollectionDetailScreen(collection: collection)),
        );
        if (result == true) _loadCollections();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -6, left: 10, right: 10, bottom: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withAlpha(120),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  top: -3, left: 5, right: 5, bottom: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: AppColors.surface,
                      child: Center(
                        child: Icon(
                          collection.collectionType == 'RESTAURANT' 
                              ? CupertinoIcons.house_fill 
                              : CupertinoIcons.square_favorites_fill,
                          size: 32, 
                          color: AppColors.textLight.withAlpha(150),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!collection.isPublic)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.black.withAlpha(120), shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.lock_fill, size: 10, color: CupertinoColors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            collection.name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2),
          ),
          const SizedBox(height: 2),
          Text(
            collection.collectionType == 'RESTAURANT' ? 'Restaurants' : 'Posts',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Failed to load collections', style: TextStyle(color: AppColors.textSecondary)),
          CupertinoButton(onPressed: _loadCollections, child: const Text('Try again')),
        ],
      ),
    );
  }

  void _showCreateCollectionSheet(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    String type = 'POST';
    bool isCreating = false;

    showCupertinoModalPopup(
      context: context,
      barrierColor: Colors.black.withAlpha(100),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 20, left: 24, right: 24,
          ),
          decoration: const BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('New Collection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Collection Name',
                autofocus: true,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              const Text('What are you saving?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TypeOption(
                    icon: CupertinoIcons.doc_text,
                    label: 'Posts',
                    isSelected: type == 'POST',
                    onTap: () => setSheetState(() => type = 'POST'),
                  ),
                  const SizedBox(width: 12),
                  _TypeOption(
                    icon: CupertinoIcons.house,
                    label: 'Restaurants',
                    isSelected: type == 'RESTAURANT',
                    onTap: () => setSheetState(() => type = 'RESTAURANT'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: isCreating ? null : () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  setSheetState(() => isCreating = true);
                  try {
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user != null) {
                      await _collectionRepository.createCollection(userId: user.id, name: name, collectionType: type);
                      if (context.mounted) { Navigator.pop(context); _loadCollections(); }
                    }
                  } catch (e) {
                    setSheetState(() => isCreating = false);
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: isCreating 
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text('Create Collection', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w700)),
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withAlpha(20) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 24),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textSecondary)),
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
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 24, childAspectRatio: 0.85,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Skeleton(borderRadius: 12)),
          SizedBox(height: 12),
          Skeleton(width: 100, height: 16),
          SizedBox(height: 4),
          Skeleton(width: 60, height: 12),
        ],
      ),
    );
  }
}
