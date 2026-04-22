import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors; // For slight shadows
import 'package:taste_spot/core/theme/app_theme.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  // Simulating tabs for "Saved Posts" and "My Albums"
  int _selectedSegment = 0;

  // Dummy data for saved collections
  final List<Map<String, dynamic>> _albums = [
    {
      'title': 'KL Cafes ☕️',
      'count': 12,
      'cover': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=800&auto=format&fit=crop',
      'isPrivate': false,
    },
    {
      'title': 'Date Night 🍷',
      'count': 8,
      'cover': 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?q=80&w=800&auto=format&fit=crop',
      'isPrivate': true,
    },
    {
      'title': 'Japan Trip 🇯🇵',
      'count': 24,
      'cover': 'https://images.unsplash.com/photo-1580822184713-fc5400e7fe10?q=80&w=800&auto=format&fit=crop',
      'isPrivate': false,
    },
    {
      'title': 'Recipes to try',
      'count': 5,
      'cover': 'https://images.unsplash.com/photo-1466637574441-749b8f19452f?q=80&w=800&auto=format&fit=crop',
      'isPrivate': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: CupertinoColors.white,
        border: null, // Clean look
        middle: const Text('Collections', style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {},
          child: const Icon(CupertinoIcons.add, size: 24, color: AppColors.textPrimary),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Segmented Control (Tabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  backgroundColor: AppColors.surface,
                  thumbColor: AppColors.primary,
                  groupValue: _selectedSegment,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Albums',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _selectedSegment == 0
                              ? CupertinoColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'All Saved',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _selectedSegment == 1
                              ? CupertinoColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) setState(() => _selectedSegment = value);
                  },
                ),
              ),
            ),

            // Content
            Expanded(
              child: _selectedSegment == 0
                  ? _buildAlbumsGrid()
                  : _buildAllSavedGrid(),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // TAB 1: ALL SAVED POSTS (Masonry Grid Style)
  // ══════════════════════════════════════════
  Widget _buildAllSavedGrid() {
    // Dummy images for grid
    final images = [
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38',
      'https://images.unsplash.com/photo-1565958011703-44f9829ba187',
      'https://images.unsplash.com/photo-1482049016688-2d3e1b311543',
      'https://images.unsplash.com/photo-1626808642875-0aa545482dfb',
      'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe',
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 0.8, // Slightly taller for "card" feel or square
      ),
      itemCount: 20,
      itemBuilder: (context, index) {
        final url = images[index % images.length];
        return GestureDetector(
          onTap: () {},
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  // TAB 2: ALBUMS GRID
  // ══════════════════════════════════════════
  Widget _buildAlbumsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index];
        return GestureDetector(
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Cover
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(album['cover']),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: album['isPrivate']
                      ? Container(
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.lock_fill,
                                size: 12, color: CupertinoColors.white),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                album['title'],
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
                '${album['count']} items',
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
}