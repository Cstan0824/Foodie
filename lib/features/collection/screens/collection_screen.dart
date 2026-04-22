import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors; // For slight shadows
import 'package:taste_spot/core/theme/app_theme.dart';
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
  bool _isLoadingCollections = true;
  String? _collectionError;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadCollections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void refreshCollections() {
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000001';

    if (mounted) {
      setState(() {
        _isLoadingCollections = true;
        _collectionError = null;
      });
    }

    try {
      final collections = await _collectionRepository.getUserCollections(
        userId,
      );
      if (mounted) {
        setState(() {
          _collections = collections;
          _isLoadingCollections = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCollections = false;
          _collectionError = e.toString();
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: CupertinoColors.white,
        border: null, // Clean look
        middle: const Text(
          'Collections',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showCreateCollectionDialog(context),
          child: const Icon(
            CupertinoIcons.add,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search collections...',
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            // Content
            Expanded(
              child: _buildAlbumsGrid(),
            ),
          ],
        ),
      ),
    );
  }



  List<Collection> get _filteredCollections {
    if (_searchQuery.isEmpty) return _collections;
    final lowerQuery = _searchQuery.toLowerCase();
    return _collections.where((c) => c.name.toLowerCase().contains(lowerQuery)).toList();
  }

  // ══════════════════════════════════════════
  // TAB 2: ALBUMS GRID
  // ══════════════════════════════════════════
  Widget _buildAlbumsGrid() {
    if (_isLoadingCollections) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_collectionError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Failed to load collections',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadCollections,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final collectionsToShow = _filteredCollections;

    if (collectionsToShow.isEmpty) {
      return Center(
        child: Text(
          _collections.isEmpty ? 'No collections yet' : 'No matches found',
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: collectionsToShow.length,
      itemBuilder: (context, index) {
        final album = collectionsToShow[index];
        return GestureDetector(
          onTap: () async {
            final result = await Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => CollectionDetailScreen(collection: album),
              ),
            );
            if (result == true) {
              _loadCollections();
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Cover
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.surface, CupertinoColors.white],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          CupertinoIcons.collections,
                          size: 34,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (!album.isPublic)
                        Container(
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.lock_fill,
                              size: 12,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              // Count
              Text(
                album.isPublic ? 'Public collection' : 'Private collection',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  // CREATE COLLECTION DIALOG
  // ══════════════════════════════════════════
  void _showCreateCollectionDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    bool isCreating = false;

    showCupertinoDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('New Collection'),
              content: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Collection Name',
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: isCreating
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          setDialogState(() => isCreating = true);

                          final user = Supabase.instance.client.auth.currentUser;
                          if (user != null) {
                            try {
                              await _collectionRepository.createCollection(
                                userId: user.id,
                                name: name,
                                collectionType: 'POST', // Default type
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                _loadCollections(); // Refresh list
                              }
                            } catch (e) {
                              setDialogState(() => isCreating = false);
                              print('Error creating collection: $e');
                              // Show an alert dialog with the error
                              if (context.mounted) {
                                showCupertinoDialog(
                                  context: context,
                                  builder: (_) => CupertinoAlertDialog(
                                    title: const Text('Error'),
                                    content: Text(e.toString()),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: const Text('OK'),
                                        onPressed: () => Navigator.pop(context),
                                      )
                                    ],
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isCreating
                      ? const CupertinoActivityIndicator()
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
