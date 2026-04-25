import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/search/screens/search_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taste_spot/data/repositories/search_repository.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Timer? _suggestionDebounce;
  List<SearchSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;

  static const String _searchHistoryKey = 'search_history';
  static const int _maxSearchHistoryItems = 10;

  List<String> _searchHistory = [];
  List<String> _trendingSearches = [];
  bool _isLoadingTrending = false;

  @override
  void initState() {
    super.initState();
    // Auto focus the search bar when the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
    _loadSearchHistory();
    _loadTrendingSearches();
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_searchHistoryKey) ?? <String>[];
    if (!mounted) return;
    setState(() {
      _searchHistory = items;
    });
  }

  Future<void> _saveSearchQuery(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_searchHistoryKey) ?? <String>[];
    final normalized = query.toLowerCase();

    final updated = <String>[
      query,
      ...current.where((item) => item.trim().toLowerCase() != normalized),
    ];

    final capped = updated.take(_maxSearchHistoryItems).toList();
    await prefs.setStringList(_searchHistoryKey, capped);

    if (!mounted) return;
    setState(() {
      _searchHistory = capped;
    });
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);

    if (!mounted) return;
    setState(() {
      _searchHistory = [];
    });
  }

  Future<void> _loadTrendingSearches() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTrending = true;
    });

    try {
      final items = await SearchRepository.instance.fetchTrendingSearches(
        limit: 8,
      );
      if (!mounted) return;
      setState(() {
        _trendingSearches = items;
        _isLoadingTrending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trendingSearches = [];
        _isLoadingTrending = false;
      });
    }
  }

  Future<void> _openSearchResult(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    _dismissKeyboard();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SearchResultScreen(initialQuery: query),
      ),
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
    });
  }

  Future<void> _submitSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    _suggestionDebounce?.cancel();
    if (mounted) {
      setState(() {
        _isLoadingSuggestions = false;
        _suggestions = [];
      });
    }
    await _saveSearchQuery(query);
    await _openSearchResult(query);
  }

  void _onSearchChanged(String query) {
    setState(() {});

    _suggestionDebounce?.cancel();

    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (_suggestions.isNotEmpty || _isLoadingSuggestions) {
        setState(() {
          _suggestions = [];
          _isLoadingSuggestions = false;
        });
      }
      return;
    }

    _suggestionDebounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(trimmed);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final results = await SearchRepository.instance.fetchSearchSuggestions(
        query,
      );
      if (!mounted) return;

      if (_searchController.text.trim() == query) {
        setState(() {
          _suggestions = results;
          _isLoadingSuggestions = false;
        });
      } else {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.cardBackground,
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKeyboard,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _searchController.text.isNotEmpty
                    ? _buildSearchResults()
                    : _buildSearchHistoryAndTrending(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(34, 34),
            onPressed: () {
              _dismissKeyboard();
              Navigator.of(context).maybePop();
            },
            child: const Icon(
              CupertinoIcons.back,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: CupertinoSearchTextField(
              controller: _searchController,
              focusNode: _searchFocus,
              placeholder: 'Search spots, foods, or users...',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _submitSearch,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(left: 8),
            minimumSize: const Size(34, 34),
            onPressed: () => _submitSearch(_searchController.text),
            child: const Text(
              'Search',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Search History and Trending List
  Widget _buildSearchHistoryAndTrending() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: _searchHistory.isEmpty
                      ? null
                      : _clearSearchHistory,
                  child: const Icon(
                    CupertinoIcons.trash,
                    color: AppColors.textLight,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _searchHistory
                  .map((query) => _buildChip(query))
                  .toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Trending List
          const Text(
            'Trending Searches',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTrendingList(),
        ],
      ),
    );
  }

  Widget _buildTrendingList() {
    if (_isLoadingTrending) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: CupertinoActivityIndicator(),
      );
    }

    if (_trendingSearches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No trending searches yet.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: List.generate(_trendingSearches.length, (index) {
        final title = _trendingSearches[index];
        final isHot = index < 3;

        Color numberColor;
        if (index == 0) {
          numberColor = const Color(0xFFFF3B30);
        } else if (index == 1) {
          numberColor = const Color(0xFFFF9500);
        } else if (index == 2) {
          numberColor = const Color(0xFFFFCC00);
        } else {
          numberColor = AppColors.textLight;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _searchController.text = title;
            _searchController.selection = TextSelection.fromPosition(
              TextPosition(offset: title.length),
            );
            setState(() {});
            _submitSearch(title);
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
    final query = _searchController.text.trim();
    if (query.length < 2) {
      return _buildSearchHistoryAndTrending();
    }

    if (_isLoadingSuggestions && _suggestions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final isRestaurant = suggestion.type == SearchSuggestionType.restaurant;
        final isHashtag = suggestion.type == SearchSuggestionType.hashtag;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _searchController.text = suggestion.queryText;
            _searchController.selection = TextSelection.fromPosition(
              TextPosition(offset: suggestion.queryText.length),
            );
            setState(() {});
            _submitSearch(suggestion.queryText);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isRestaurant
                      ? CupertinoIcons.map_pin_ellipse
                      : (isHashtag
                            ? CupertinoIcons.number
                            : CupertinoIcons.search),
                  color: AppColors.textLight,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    suggestion.displayText,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.arrow_up_left,
                  size: 14,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(String text) {
    return GestureDetector(
      onTap: () {
        _searchController.text = text;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
        setState(() {}); // trigger search visually
        _submitSearch(text);
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
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
