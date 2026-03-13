import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  final List<String> _searchHistory = [
    'Spicy noodles',
    'Hidden gems KL',
    'Oji Matcha',
    'Bakery near me'
  ];

  @override
  void initState() {
    super.initState();
    // Auto focus the search bar when the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.98),
        border: null,
        middle: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: CupertinoSearchTextField(
            controller: _searchController,
            focusNode: _searchFocus,
            placeholder: 'Search spots, foods, or users...',
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            onChanged: (val) {
              setState(() {});
            },
            onSubmitted: (val) {
              // Submit search logic
              setState(() {});
            },
          ),
        ),
      ),
      child: SafeArea(
        child: _searchController.text.isNotEmpty 
            ? _buildSearchResults()
            : _buildSearchHistoryAndTrending(), 
      ),
    );
  }

  // 1. Search History and Trending List
  Widget _buildSearchHistoryAndTrending() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // History
          if (_searchHistory.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Search History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    setState(() => _searchHistory.clear());
                  },
                  child: const Icon(CupertinoIcons.trash, color: AppColors.textLight, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _searchHistory.map((query) => _buildChip(query)).toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Trending List
          const Text(
            'Trending Searches',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildTrendingList(),
        ],
      ),
    );
  }

  Widget _buildTrendingList() {
    final trendingItems = [
      {'title': 'Hotpot buffet KL', 'hot': true},
      {'title': 'Best brunch spots PJ', 'hot': true},
      {'title': 'Hidden speakeasy bars', 'hot': false},
      {'title': 'Matcha deserts near me', 'hot': false},
      {'title': 'Omakase budget friendly', 'hot': false},
      {'title': 'Night market food', 'hot': false},
      {'title': 'Pet friendly cafes', 'hot': false},
      {'title': 'Spicy ramen challenge', 'hot': false},
    ];

    return Column(
      children: List.generate(trendingItems.length, (index) {
        final item = trendingItems[index];
        final isHot = item['hot'] as bool;
        final title = item['title'] as String;

        Color numberColor;
        if (index == 0) {
          numberColor = const Color(0xFFFF3B30); // Red
        } else if (index == 1) {
          numberColor = const Color(0xFFFF9500); // Orange
        } else if (index == 2) {
          numberColor = const Color(0xFFFFCC00); // Yellow
        } else {
          numberColor = AppColors.textLight;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _searchController.text = title;
            setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: index < 3 ? FontWeight.bold : FontWeight.w500,
                      color: numberColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isHot)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'HOT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // 2. Results when user types (Mock data)
  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: 4, 
      itemBuilder: (context, index) {
        return CupertinoListTile(
          title: Text('${_searchController.text} result ${index + 1}'),
          subtitle: const Text('Found in restaurants & reviews'),
          leading: const Icon(CupertinoIcons.search, color: AppColors.textLight),
          onTap: () {
            _searchFocus.unfocus();
          },
        );
      },
    );
  }

  Widget _buildChip(String text) {
    return GestureDetector(
      onTap: () {
        _searchController.text = text;
        setState(() {}); // trigger search visually
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}