import 'dart:math';

import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';

enum SearchSuggestionType { restaurant, post, hashtag }

class SearchSuggestion {
  final SearchSuggestionType type;
  final String displayText;
  final String queryText;
  final String? restaurantId;
  final String? postId;

  const SearchSuggestion({
    required this.type,
    required this.displayText,
    required this.queryText,
    this.restaurantId,
    this.postId,
  });
}

enum SearchScope { all, restaurants, posts }

enum SearchSortMode { top, latest, nearby }

enum RestaurantMatchBucket { none, r1, r2, r3, r4 }

enum PostMatchBucket { irrelevant, p1, p2, p3, p4, p5, p6 }

class RestaurantSearchResult {
  final RestaurantModel restaurant;
  final RestaurantMatchBucket bucket;
  final double score;
  final double? distanceKm;
  final bool isStrongEntityMatch;

  const RestaurantSearchResult({
    required this.restaurant,
    required this.bucket,
    required this.score,
    required this.distanceKm,
    required this.isStrongEntityMatch,
  });
}

class PostSearchResult {
  final PostModel post;
  final PostMatchBucket bucket;
  final bool boostedByRestaurantMatch;
  final double exactScore;
  final double relevanceScore;
  final double engagementScore;
  final double freshnessScore;
  final double totalScore;
  final double? distanceKm;

  const PostSearchResult({
    required this.post,
    required this.bucket,
    required this.boostedByRestaurantMatch,
    required this.exactScore,
    required this.relevanceScore,
    required this.engagementScore,
    required this.freshnessScore,
    required this.totalScore,
    required this.distanceKm,
  });
}

class SearchResultsPayload {
  final String query;
  final SearchScope scope;
  final List<RestaurantSearchResult> restaurants;
  final List<PostSearchResult> posts;

  const SearchResultsPayload({
    required this.query,
    required this.scope,
    required this.restaurants,
    required this.posts,
  });
}

class SearchRepository {
  SearchRepository._();
  static final SearchRepository instance = SearchRepository._();

  static const String _restaurantSelect = '''
		restaurant_Id,
		restaurant_name,
		address,
		latitude,
		longitude,
		maps_url,
		created_At,
		main_cuisine_id,
		source,
		info_url,
		isDisabled,
		rating,
		mainCuisine:Cuisine!restaurant_main_cuisine_fk(type_id, desc),
		Restaurant_Image(image_id, image_url, isCover)
	''';

  static const String _postSearchSelect = '''
		post_Id,
		user_Id,
		restaurant_Id,
		restaurant_approval_id,
		title,
		caption,
		likeCount,
		saveCount,
		created_At,
		User!Post_user_Id_fkey(user_Id, name),
		Restaurant!inner(
      restaurant_Id,
      restaurant_name,
      address,
      latitude,
      longitude,
      isDisabled
    ),
		Post_Image(image_Id, image_url)
	''';
  static const int _minimumPostResults = 10;

  Future<SearchResultsPayload> search({
    required String query,
    SearchScope scope = SearchScope.all,
    SearchSortMode sortMode = SearchSortMode.top,
    double? userLatitude,
    double? userLongitude,
    int restaurantPreviewLimit = 3,
    int restaurantLimit = 30,
    int postLimit = 60,
  }) async {
    final restaurantScopedName = _extractRestaurantScopedQuery(query);
    if (restaurantScopedName != null) {
      return _searchPostsForRestaurant(
        restaurantName: restaurantScopedName,
        query: query,
        scope: scope,
        sortMode: sortMode,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        postLimit: postLimit,
      );
    }

    final normalizedQuery = _normalizeText(query);
    final tokens = _tokenize(normalizedQuery);
    final hashtagIntent = _normalizedHashtagIntentFromQuery(query);

    if (normalizedQuery.isEmpty) {
      return SearchResultsPayload(
        query: query,
        scope: scope,
        restaurants: const [],
        posts: const [],
      );
    }

    List<RestaurantSearchResult> rankedRestaurants = const [];
    if (scope == SearchScope.all || scope == SearchScope.restaurants) {
      final restaurantCandidates = await _fetchRestaurantCandidates(
        rawQuery: query,
        normalizedQuery: normalizedQuery,
        tokens: tokens,
      );
      rankedRestaurants = _rankRestaurants(
        restaurantCandidates,
        normalizedQuery,
        tokens,
        sortMode: sortMode,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
    }

    final strongRestaurantMatches = rankedRestaurants
        .where((r) => r.isStrongEntityMatch)
        .toList();
    final strongRestaurantIds = strongRestaurantMatches
        .map((r) => r.restaurant.restaurantId)
        .toSet();

    List<PostSearchResult> rankedPosts = const [];
    if (scope == SearchScope.all || scope == SearchScope.posts) {
      final postCandidates = await _fetchPostCandidates(
        rawQuery: query,
        tokens: tokens,
        boostedRestaurantIds: strongRestaurantIds,
      );

      final userId = SupabaseService.currentUserId;
      final postIds = postCandidates
          .map((r) => r['post_Id']?.toString())
          .whereType<String>()
          .toList();
      final interactionProfile = userId == null || postIds.isEmpty
          ? const _PostInteractionProfile.empty()
          : await _buildPostInteractionProfile(userId, postIds);

      rankedPosts = _rankPosts(
        postCandidates,
        normalizedQuery,
        tokens,
        hashtagIntent: hashtagIntent,
        boostedRestaurantIds: strongRestaurantIds,
        sortMode: sortMode,
        interactionProfile: interactionProfile,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );

      if (rankedPosts.length < _minimumPostResults) {
        rankedPosts = await _appendFallbackPosts(
          rankedPosts,
          minimumCount: _minimumPostResults,
          sortMode: sortMode,
          existingProfile: interactionProfile,
          userLatitude: userLatitude,
          userLongitude: userLongitude,
        );
      }
    }

    final hasExactHashtagPostMatch =
        hashtagIntent != null &&
        rankedPosts.any((p) => _postHasExactHashtag(p.post, hashtagIntent));

    final shouldShowRestaurantPreview =
        scope == SearchScope.all &&
        !hasExactHashtagPostMatch &&
        _shouldShowRestaurantPreview(rankedRestaurants, tokens);

    final restaurants = switch (scope) {
      SearchScope.restaurants =>
        rankedRestaurants.take(restaurantLimit).toList(),
      SearchScope.posts => const <RestaurantSearchResult>[],
      SearchScope.all =>
        shouldShowRestaurantPreview
            ? rankedRestaurants.take(restaurantPreviewLimit).toList()
            : const <RestaurantSearchResult>[],
    };

    final posts = switch (scope) {
      SearchScope.restaurants => const <PostSearchResult>[],
      SearchScope.posts => rankedPosts.take(postLimit).toList(),
      SearchScope.all => rankedPosts.take(postLimit).toList(),
    };

    return SearchResultsPayload(
      query: query,
      scope: scope,
      restaurants: restaurants,
      posts: posts,
    );
  }

  String? _extractRestaurantScopedQuery(String rawQuery) {
    final trimmed = rawQuery.trim();
    final lower = trimmed.toLowerCase();

    if (!lower.startsWith('restaurant:')) return null;

    final value = trimmed.substring('restaurant:'.length).trim();
    return value.isEmpty ? null : value;
  }

  Future<SearchResultsPayload> _searchPostsForRestaurant({
    required String restaurantName,
    required String query,
    required SearchScope scope,
    required SearchSortMode sortMode,
    double? userLatitude,
    double? userLongitude,
    required int postLimit,
  }) async {
    final normalizedRestaurantName = _normalizeText(restaurantName);
    final restaurantTokens = _tokenize(normalizedRestaurantName);

    final restaurantCandidates = await _fetchRestaurantCandidates(
      rawQuery: restaurantName,
      normalizedQuery: normalizedRestaurantName,
      tokens: restaurantTokens,
    );

    final resultRestaurants = _rankRestaurants(
      restaurantCandidates,
      normalizedRestaurantName,
      restaurantTokens,
      sortMode: sortMode,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
    );

    final matchedRestaurantId = resultRestaurants.isNotEmpty
        ? resultRestaurants.first.restaurant.restaurantId
        : null;

    if (matchedRestaurantId == null) {
      return SearchResultsPayload(
        query: query,
        scope: scope,
        restaurants: const [],
        posts: const [],
      );
    }

    // Now, fetch posts directly linked to that specific restaurant ID.
    final postRows = await SupabaseService.client
        .from('Post')
        .select(_postSearchSelect)
        .eq('isPending', false)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('Restaurant.isDisabled', false)
        .eq('restaurant_Id', matchedRestaurantId)
        .limit(postLimit * 2);

    final mappedRows = (postRows as List<dynamic>)
        .map((r) => r as Map<String, dynamic>)
        .toList();

    final userId = SupabaseService.currentUserId;
    final postIds = mappedRows
        .map((r) => r['post_Id']?.toString())
        .whereType<String>()
        .toList();
    final interactionProfile = userId == null || postIds.isEmpty
        ? const _PostInteractionProfile.empty()
        : await _buildPostInteractionProfile(userId, postIds);

    final ranked = mappedRows.map((row) {
      final post = PostModel.fromJson(row);
      final engagementRaw = post.likes + (post.saveCount * 2);
      final engagementScore = min(60.0, log(1 + engagementRaw) * 12);

      final ageHours = post.createdAt != null
          ? max(
              0.0,
              DateTime.now().difference(post.createdAt!).inHours.toDouble(),
            )
          : 720.0;
      final freshnessScore = 30.0 / (1 + (ageHours / 24.0));

      final interactionPenalty = _interactionPenalty(
        post.id,
        interactionProfile,
      );
      final distanceKm = _distanceForPost(
        post,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
      final locationBoost = sortMode == SearchSortMode.top
          ? _locationBoostForSearch(distanceKm)
          : 0.0;

      final totalScore =
          engagementScore + freshnessScore + locationBoost - interactionPenalty;

      return PostSearchResult(
        post: post,
        bucket: PostMatchBucket.p1,
        boostedByRestaurantMatch: true,
        exactScore: 100,
        relevanceScore: 100,
        engagementScore: engagementScore,
        freshnessScore: freshnessScore,
        totalScore: totalScore,
        distanceKm: distanceKm,
      );
    }).toList();

    ranked.sort((a, b) {
      if (sortMode == SearchSortMode.nearby) {
        final distanceCompare = _compareDistanceAsc(a.distanceKm, b.distanceKm);
        if (distanceCompare != 0) return distanceCompare;
      }

      if (sortMode == SearchSortMode.latest) {
        final createdA = a.post.createdAt;
        final createdB = b.post.createdAt;
        if (createdA == null && createdB == null) return 0;
        if (createdA == null) return 1;
        if (createdB == null) return -1;
        return createdB.compareTo(createdA);
      }

      final totalCompare = b.totalScore.compareTo(a.totalScore);
      if (totalCompare != 0) return totalCompare;

      return b.post.likes.compareTo(a.post.likes);
    });

    final scopedRestaurants = switch (scope) {
      SearchScope.all => resultRestaurants.take(1).toList(),
      SearchScope.restaurants => resultRestaurants.take(10).toList(),
      SearchScope.posts => const <RestaurantSearchResult>[],
    };

    final scopedPosts = switch (scope) {
      SearchScope.all => ranked.take(postLimit).toList(),
      SearchScope.restaurants => const <PostSearchResult>[],
      SearchScope.posts => ranked.take(postLimit).toList(),
    };

    return SearchResultsPayload(
      query: query,
      scope: scope,
      restaurants: scopedRestaurants,
      posts: scopedPosts,
    );
  }

  Future<SearchResultsPayload> searchAll({
    required String query,
    SearchSortMode sortMode = SearchSortMode.top,
    int restaurantPreviewLimit = 3,
    int postLimit = 60,
  }) {
    return search(
      query: query,
      scope: SearchScope.all,
      sortMode: sortMode,
      restaurantPreviewLimit: restaurantPreviewLimit,
      postLimit: postLimit,
    );
  }

  Future<List<RestaurantSearchResult>> searchRestaurantsOnly({
    required String query,
    SearchSortMode sortMode = SearchSortMode.top,
    int limit = 30,
  }) async {
    final result = await search(
      query: query,
      scope: SearchScope.restaurants,
      sortMode: sortMode,
      restaurantLimit: limit,
    );
    return result.restaurants;
  }

  Future<List<PostSearchResult>> searchPostsOnly({
    required String query,
    SearchSortMode sortMode = SearchSortMode.top,
    int limit = 60,
  }) async {
    final result = await search(
      query: query,
      scope: SearchScope.posts,
      sortMode: sortMode,
      postLimit: limit,
    );
    return result.posts;
  }

  Future<List<SearchSuggestion>> fetchSearchSuggestions(String query) async {
    final normalizedQuery = _normalizeText(query);
    if (normalizedQuery.length < 2) return const [];

    final safeQuery = _toSafeIlikeInput(query);
    if (safeQuery.isEmpty) return const [];

    final suggestions = <SearchSuggestion>[];
    final hashtagSuggestion = _buildHashtagSuggestion(normalizedQuery);

    // 1. Fetch restaurant candidates
    final restaurantRows = await SupabaseService.client
        .from('Restaurant')
        .select('restaurant_Id, restaurant_name, address')
        .eq('isDisabled', false)
        .or('restaurant_name.ilike.%$safeQuery%,address.ilike.%$safeQuery%')
        .limit(25);

    final restaurantSuggestions = (restaurantRows as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      final name = (map['restaurant_name'] as String?) ?? '';
      final address = (map['address'] as String?) ?? '';
      final nameNorm = _normalizeText(name);
      final addressNorm = _normalizeText(address);
      final queryNorm = normalizedQuery;
      final tokens = _tokenize(queryNorm);
      final nameWords = _wordSet(nameNorm);
      final addressWords = _wordSet(addressNorm);

      double score = 0;
      if (nameNorm == queryNorm) {
        score += 120;
      } else if (nameNorm.startsWith(queryNorm) && queryNorm.isNotEmpty) {
        score += 100;
      } else if (queryNorm.isNotEmpty && nameNorm.contains(queryNorm)) {
        score += 90;
      }

      score += _tokenOverlapRatio(tokens, nameWords) * 30;

      if (queryNorm.isNotEmpty && addressNorm.contains(queryNorm)) {
        score += 45;
      }
      score += _tokenOverlapRatio(tokens, addressWords) * 15;

      final fuzzyBest = max(
        _fuzzySimilarity(queryNorm, nameNorm),
        _fuzzySimilarity(queryNorm, addressNorm),
      );
      score += fuzzyBest * 10;

      return (
        suggestion: SearchSuggestion(
          type: SearchSuggestionType.restaurant,
          displayText: name,
          queryText: name,
          restaurantId: map['restaurant_Id'] as String,
        ),
        score: score,
      );
    }).toList();

    restaurantSuggestions.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.suggestion.displayText.toLowerCase().compareTo(
        b.suggestion.displayText.toLowerCase(),
      );
    });

    final uniqueRestaurants = <String, SearchSuggestion>{};
    for (final r in restaurantSuggestions) {
      final key = r.suggestion.displayText.toLowerCase();
      if (!uniqueRestaurants.containsKey(key)) {
        uniqueRestaurants[key] = r.suggestion;
      }
    }

    suggestions.addAll(uniqueRestaurants.values.take(3));

    // 2. Fetch post candidates
    try {
      final postRows = await SupabaseService.client
          .from('Post')
          .select(
            'post_Id, title, caption, likeCount, saveCount, created_At, Restaurant!inner(isDisabled)',
          )
          .eq('isPending', false)
          .eq('isRemoved', false)
          .eq('isBlocked', false)
          .eq('Restaurant.isDisabled', false)
          .or('title.ilike.%$safeQuery%,caption.ilike.%$safeQuery%')
          .limit(25);

      final posts = (postRows as List<dynamic>)
          .map((row) {
            final map = row as Map<String, dynamic>;
            final title = (map['title'] as String?) ?? '';
            final caption = (map['caption'] as String?) ?? '';

            final titleNorm = _normalizeText(title);
            final captionNorm = _normalizeText(caption);

            double score = 0;
            if (normalizedQuery.isNotEmpty &&
                titleNorm.contains(normalizedQuery)) {
              score += 100;
            }
            if (normalizedQuery.isNotEmpty &&
                captionNorm.contains(normalizedQuery)) {
              score += 65;
            }

            final tokens = _tokenize(normalizedQuery);
            score += _tokenOverlapRatio(tokens, _wordSet(titleNorm)) * 25;
            score += _tokenOverlapRatio(tokens, _wordSet(captionNorm)) * 12;

            final likeCount = (map['likeCount'] as num?)?.toInt() ?? 0;
            final saveCount = (map['saveCount'] as num?)?.toInt() ?? 0;
            final createdAtRaw = map['created_At']?.toString();
            final createdAt = createdAtRaw == null
                ? null
                : DateTime.tryParse(createdAtRaw);

            return (
              suggestion: SearchSuggestion(
                type: SearchSuggestionType.post,
                displayText: title,
                queryText: title,
                postId: map['post_Id'] as String,
              ),
              score: score,
              likeCount: likeCount,
              saveCount: saveCount,
              createdAt: createdAt,
            );
          })
          .where((item) => item.suggestion.displayText.trim().isNotEmpty)
          .toList();

      posts.sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;

        final aEngage = a.likeCount + (a.saveCount * 2);
        final bEngage = b.likeCount + (b.saveCount * 2);
        if (aEngage != bEngage) return bEngage.compareTo(aEngage);

        final createdA = a.createdAt;
        final createdB = b.createdAt;
        if (createdA == null && createdB == null) return 0;
        if (createdA == null) return 1;
        if (createdB == null) return -1;
        return createdB.compareTo(createdA);
      });

      final uniquePosts = <String, SearchSuggestion>{};
      for (final p in posts) {
        final key = p.suggestion.displayText.toLowerCase();
        if (!uniquePosts.containsKey(key)) {
          uniquePosts[key] = p.suggestion;
        }
      }

      suggestions.addAll(uniquePosts.values.take(3));
    } catch (_) {
      // Keep restaurant suggestions working even if post suggestion query fails.
    }

    if (hashtagSuggestion != null) {
      suggestions.insert(0, hashtagSuggestion);
    }

    final deduped = <SearchSuggestion>[];
    final seen = <String>{};
    for (final suggestion in suggestions) {
      final key = suggestion.queryText.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      deduped.add(suggestion);
    }

    return deduped.take(6).toList();
  }

  Future<List<String>> fetchTrendingSearches({int limit = 8}) async {
    final rows = await SupabaseService.client
        .from('Post')
        .select(_postSearchSelect)
        .eq('isPending', false)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('Restaurant.isDisabled', false)
        .limit(120);

    final posts = (rows as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();

    posts.sort((a, b) => _trendingScore(b).compareTo(_trendingScore(a)));

    final results = <String>[];
    final seen = <String>{};

    for (final post in posts) {
      final cleaned = _cleanTrendingTitle(post.title);
      if (cleaned == null) continue;

      final key = cleaned.toLowerCase();
      if (seen.contains(key)) continue;

      seen.add(key);
      results.add(cleaned);

      if (results.length >= limit) break;
    }

    return results;
  }

  Future<List<RestaurantModel>> _fetchRestaurantCandidates({
    required String rawQuery,
    required String normalizedQuery,
    required List<String> tokens,
    int baseLimit = 120,
  }) async {
    final out = <String, RestaurantModel>{};
    final safeQuery = _toSafeIlikeInput(rawQuery);

    if (safeQuery.isNotEmpty) {
      final directRows = await SupabaseService.client
          .from('Restaurant')
          .select(_restaurantSelect)
          .eq('isDisabled', false)
          .or('restaurant_name.ilike.%$safeQuery%,address.ilike.%$safeQuery%')
          .limit(baseLimit);

      _addRestaurantsToMap(out, directRows as List<dynamic>);
    }

    for (final token in tokens.take(4)) {
      if (token.length < 3) continue;
      final tokenRows = await SupabaseService.client
          .from('Restaurant')
          .select(_restaurantSelect)
          .eq('isDisabled', false)
          .or('restaurant_name.ilike.%$token%,address.ilike.%$token%')
          .limit(40);

      _addRestaurantsToMap(out, tokenRows as List<dynamic>);
    }

    // Fuzzy fallback candidate pool: recent active restaurants.
    final recentRows = await SupabaseService.client
        .from('Restaurant')
        .select(_restaurantSelect)
        .eq('isDisabled', false)
        .order('created_At', ascending: false)
        .limit(max(60, baseLimit ~/ 2));
    _addRestaurantsToMap(out, recentRows as List<dynamic>);

    final list = out.values.toList();
    if (normalizedQuery.isNotEmpty && list.length > 250) {
      return list.take(250).toList();
    }
    return list;
  }

  void _addRestaurantsToMap(
    Map<String, RestaurantModel> map,
    List<dynamic> rows,
  ) {
    for (final row in rows) {
      final model = RestaurantModel.fromJson(row as Map<String, dynamic>);
      map[model.restaurantId] = model;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPostCandidates({
    required String rawQuery,
    required List<String> tokens,
    required Set<String> boostedRestaurantIds,
    int baseLimit = 200,
  }) async {
    final out = <String, Map<String, dynamic>>{};
    final safeQuery = _toSafeIlikeInput(rawQuery);

    if (safeQuery.isNotEmpty) {
      final directRows = await SupabaseService.client
          .from('Post')
          .select(_postSearchSelect)
          .eq('isPending', false)
          .eq('isRemoved', false)
          .eq('isBlocked', false)
          .eq('Restaurant.isDisabled', false)
          .or('title.ilike.%$safeQuery%,caption.ilike.%$safeQuery%')
          .limit(baseLimit);

      _addPostRowsToMap(out, directRows as List<dynamic>);
    }

    for (final token in tokens.take(4)) {
      if (token.length < 3) continue;
      final tokenRows = await SupabaseService.client
          .from('Post')
          .select(_postSearchSelect)
          .eq('isPending', false)
          .eq('isRemoved', false)
          .eq('isBlocked', false)
          .eq('Restaurant.isDisabled', false)
          .or('title.ilike.%$token%,caption.ilike.%$token%')
          .limit(60);

      _addPostRowsToMap(out, tokenRows as List<dynamic>);
    }

    if (boostedRestaurantIds.isNotEmpty) {
      final linkedRows = await SupabaseService.client
          .from('Post')
          .select(_postSearchSelect)
          .eq('isPending', false)
          .eq('isRemoved', false)
          .eq('isBlocked', false)
          .eq('Restaurant.isDisabled', false)
          .inFilter('restaurant_Id', boostedRestaurantIds.toList())
          .limit(150);

      _addPostRowsToMap(out, linkedRows as List<dynamic>);
    }

    // Fallback pool so restaurant/address matches can still surface post-first results.
    final recentRows = await SupabaseService.client
        .from('Post')
        .select(_postSearchSelect)
        .eq('isPending', false)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('Restaurant.isDisabled', false)
        .order('created_At', ascending: false)
        .limit(baseLimit);

    _addPostRowsToMap(out, recentRows as List<dynamic>);
    return out.values.toList();
  }

  void _addPostRowsToMap(
    Map<String, Map<String, dynamic>> map,
    List<dynamic> rows,
  ) {
    for (final row in rows) {
      final casted = row as Map<String, dynamic>;
      final id = casted['post_Id']?.toString();
      if (id == null || id.isEmpty) continue;
      map[id] = casted;
    }
  }

  List<RestaurantSearchResult> _rankRestaurants(
    List<RestaurantModel> candidates,
    String normalizedQuery,
    List<String> tokens, {
    required SearchSortMode sortMode,
    double? userLatitude,
    double? userLongitude,
  }) {
    final results = <RestaurantSearchResult>[];

    for (final restaurant in candidates) {
      final nameNorm = _normalizeText(restaurant.name);
      final addressNorm = _normalizeText(restaurant.address ?? '');

      final nameWordSet = _wordSet(nameNorm);
      final addressWordSet = _wordSet(addressNorm);

      final nameExact = nameNorm == normalizedQuery;
      final nameContainsPhrase =
          normalizedQuery.isNotEmpty && nameNorm.contains(normalizedQuery);
      final nameStartsWithPhrase = nameNorm.startsWith(normalizedQuery);

      final nameOverlap = _tokenOverlapRatio(tokens, nameWordSet);
      final addressOverlap = _tokenOverlapRatio(tokens, addressWordSet);
      final addressContainsPhrase =
          normalizedQuery.isNotEmpty && addressNorm.contains(normalizedQuery);

      final fuzzyName = _fuzzySimilarity(normalizedQuery, nameNorm);
      final fuzzyAddress = _fuzzySimilarity(normalizedQuery, addressNorm);
      final fuzzyBest = max(fuzzyName, fuzzyAddress);

      RestaurantMatchBucket bucket = RestaurantMatchBucket.none;
      double score = 0;

      if (nameExact ||
          nameStartsWithPhrase ||
          (nameContainsPhrase && normalizedQuery.length >= 4)) {
        bucket = RestaurantMatchBucket.r1;
        score = 100 + (nameExact ? 20 : 0) + (nameOverlap * 10);
      } else if (nameOverlap >= 0.6 ||
          (_matchedTokenCount(tokens, nameWordSet) >= 2 &&
              tokens.length >= 2)) {
        bucket = RestaurantMatchBucket.r2;
        score = 80 + (nameOverlap * 20);
      } else if (addressContainsPhrase || addressOverlap >= 0.6) {
        bucket = RestaurantMatchBucket.r3;
        score = 65 + (addressOverlap * 20);
      } else if (fuzzyBest >= 0.82) {
        bucket = RestaurantMatchBucket.r4;
        score = 45 + (fuzzyBest * 10);
      }

      if (bucket == RestaurantMatchBucket.none) continue;

      final distanceKm = _distanceForRestaurant(
        restaurant,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
      final locationBoost = sortMode == SearchSortMode.top
          ? _locationBoostForSearch(distanceKm)
          : 0.0;

      results.add(
        RestaurantSearchResult(
          restaurant: restaurant,
          bucket: bucket,
          score: score + locationBoost,
          distanceKm: distanceKm,
          isStrongEntityMatch: bucket != RestaurantMatchBucket.r4,
        ),
      );
    }

    results.sort((a, b) {
      final bucketCompare = _restaurantBucketPriority(
        b.bucket,
      ).compareTo(_restaurantBucketPriority(a.bucket));
      if (bucketCompare != 0) return bucketCompare;

      if (sortMode == SearchSortMode.nearby) {
        final distanceCompare = _compareDistanceAsc(a.distanceKm, b.distanceKm);
        if (distanceCompare != 0) return distanceCompare;
      }

      if (sortMode == SearchSortMode.latest) {
        final createdA = a.restaurant.createdAt;
        final createdB = b.restaurant.createdAt;
        if (createdA == null && createdB == null) return 0;
        if (createdA == null) return 1;
        if (createdB == null) return -1;
        return createdB.compareTo(createdA);
      }

      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;

      final ratingA = a.restaurant.rating ?? 0;
      final ratingB = b.restaurant.rating ?? 0;
      final ratingCompare = ratingB.compareTo(ratingA);
      if (ratingCompare != 0) return ratingCompare;

      final createdA = a.restaurant.createdAt;
      final createdB = b.restaurant.createdAt;
      if (createdA == null && createdB == null) return 0;
      if (createdA == null) return 1;
      if (createdB == null) return -1;
      return createdB.compareTo(createdA);
    });

    return results;
  }

  List<PostSearchResult> _rankPosts(
    List<Map<String, dynamic>> rows,
    String normalizedQuery,
    List<String> tokens, {
    required String? hashtagIntent,
    required Set<String> boostedRestaurantIds,
    required SearchSortMode sortMode,
    required _PostInteractionProfile interactionProfile,
    double? userLatitude,
    double? userLongitude,
  }) {
    final ranked = <PostSearchResult>[];
    final hasStrongEntityRestaurantMatch = boostedRestaurantIds.isNotEmpty;

    for (final row in rows) {
      final post = PostModel.fromJson(row);
      final restaurant = row['Restaurant'] as Map<String, dynamic>?;

      final titleNorm = _normalizeText(post.title);
      final captionNorm = _normalizeText(post.description);
      final restaurantNameNorm = _normalizeText(
        restaurant?['restaurant_name']?.toString() ?? post.restaurantName,
      );
      final restaurantAddressNorm = _normalizeText(
        restaurant?['address']?.toString() ?? '',
      );

      final titleWordSet = _wordSet(titleNorm);
      final captionWordSet = _wordSet(captionNorm);
      final restaurantNameWordSet = _wordSet(restaurantNameNorm);
      final restaurantAddressWordSet = _wordSet(restaurantAddressNorm);

      final phraseInTitle =
          normalizedQuery.isNotEmpty && titleNorm.contains(normalizedQuery);
      final phraseInCaption =
          normalizedQuery.isNotEmpty && captionNorm.contains(normalizedQuery);

      final hasExactHashtagMatch =
          hashtagIntent != null && _postHasExactHashtag(post, hashtagIntent);

      final restaurantNameExactish =
          restaurantNameNorm == normalizedQuery ||
          restaurantNameNorm.startsWith(normalizedQuery) ||
          (normalizedQuery.isNotEmpty &&
              restaurantNameNorm.contains(normalizedQuery) &&
              normalizedQuery.length >= 4);

      final restaurantAddressStrong =
          normalizedQuery.isNotEmpty &&
          (restaurantAddressNorm.contains(normalizedQuery) ||
              _tokenOverlapRatio(tokens, restaurantAddressWordSet) >= 0.6);

      final tokenRelevance = _postTokenRelevance(
        tokens: tokens,
        titleWords: titleWordSet,
        captionWords: captionWordSet,
        restaurantNameWords: restaurantNameWordSet,
        restaurantAddressWords: restaurantAddressWordSet,
      );

      final relevanceScore =
          tokenRelevance +
          (phraseInTitle ? 3.0 : 0) +
          (phraseInCaption ? 2.0 : 0) +
          (restaurantNameExactish ? 2.0 : 0) +
          (restaurantAddressStrong ? 1.5 : 0);

      PostMatchBucket bucket = PostMatchBucket.irrelevant;
      double exactScore = 0;

      if (hasExactHashtagMatch) {
        bucket = PostMatchBucket.p1;
        exactScore = 760;
      } else if (phraseInTitle) {
        bucket = PostMatchBucket.p1;
        exactScore = 600;
      } else if (phraseInCaption) {
        bucket = PostMatchBucket.p2;
        exactScore = 520;
      } else if (restaurantNameExactish) {
        bucket = PostMatchBucket.p3;
        exactScore = 480;
      } else if (restaurantAddressStrong) {
        bucket = PostMatchBucket.p4;
        exactScore = 440;
      } else if (relevanceScore >= 3.4) {
        bucket = PostMatchBucket.p5;
        exactScore = 300;
      } else if (relevanceScore > 0) {
        bucket = PostMatchBucket.p6;
        exactScore = 180;
      }

      if (bucket == PostMatchBucket.irrelevant) continue;

      final engagementRaw = post.likes + (post.saveCount * 2);
      final engagementScore = min(60.0, log(1 + engagementRaw) * 12);

      final ageHours = post.createdAt != null
          ? max(
              0.0,
              DateTime.now().difference(post.createdAt!).inHours.toDouble(),
            )
          : 720.0;
      final freshnessScore = 30.0 / (1 + (ageHours / 24.0));

      final isBoosted =
          hasStrongEntityRestaurantMatch &&
          post.restaurantId != null &&
          boostedRestaurantIds.contains(post.restaurantId);
      final restaurantBoostScore = isBoosted ? 45.0 : 0.0;
      final distanceKm = _distanceForPost(
        post,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
      final locationBoost = sortMode == SearchSortMode.top
          ? _locationBoostForSearch(distanceKm)
          : 0.0;

      final interactionPenalty = _interactionPenalty(
        post.id,
        interactionProfile,
      );

      final totalScore =
          exactScore +
          (relevanceScore * 12.0) +
          restaurantBoostScore +
          locationBoost +
          engagementScore +
          freshnessScore -
          interactionPenalty;

      ranked.add(
        PostSearchResult(
          post: post,
          bucket: bucket,
          boostedByRestaurantMatch: isBoosted,
          exactScore: exactScore,
          relevanceScore: relevanceScore,
          engagementScore: engagementScore,
          freshnessScore: freshnessScore,
          totalScore: totalScore,
          distanceKm: distanceKm,
        ),
      );
    }

    ranked.sort((a, b) {
      final bucketCompare = _postBucketPriority(
        b.bucket,
      ).compareTo(_postBucketPriority(a.bucket));
      if (bucketCompare != 0) return bucketCompare;

      if (sortMode == SearchSortMode.nearby) {
        final distanceCompare = _compareDistanceAsc(a.distanceKm, b.distanceKm);
        if (distanceCompare != 0) return distanceCompare;
      }

      if (sortMode == SearchSortMode.latest) {
        final createdA = a.post.createdAt;
        final createdB = b.post.createdAt;
        if (createdA == null && createdB == null) return 0;
        if (createdA == null) return 1;
        if (createdB == null) return -1;
        return createdB.compareTo(createdA);
      }

      final totalCompare = b.totalScore.compareTo(a.totalScore);
      if (totalCompare != 0) return totalCompare;

      return b.post.likes.compareTo(a.post.likes);
    });

    return ranked;
  }

  Future<List<PostSearchResult>> _appendFallbackPosts(
    List<PostSearchResult> rankedPosts, {
    required int minimumCount,
    required SearchSortMode sortMode,
    required _PostInteractionProfile existingProfile,
    double? userLatitude,
    double? userLongitude,
  }) async {
    if (rankedPosts.length >= minimumCount) return rankedPosts;

    final existingIds = rankedPosts.map((p) => p.post.id).toSet();
    final needed = minimumCount - rankedPosts.length;
    final fallbackRows = await _fetchFallbackPostRows(
      excludePostIds: existingIds,
      sortMode: sortMode,
      limit: max(needed * 3, needed),
    );

    if (fallbackRows.isEmpty) return rankedPosts;

    final userId = SupabaseService.currentUserId;
    final fallbackPostIds = fallbackRows
        .map((r) => r['post_Id']?.toString())
        .whereType<String>()
        .toList();
    final fallbackProfile = userId == null || fallbackPostIds.isEmpty
        ? const _PostInteractionProfile.empty()
        : await _buildPostInteractionProfile(userId, fallbackPostIds);

    final fallbackRanked = _rankFallbackPosts(
      fallbackRows,
      sortMode: sortMode,
      interactionProfile: fallbackProfile,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
    ).where((p) => !existingIds.contains(p.post.id)).take(needed).toList();

    if (fallbackRanked.isEmpty) return rankedPosts;
    return [...rankedPosts, ...fallbackRanked];
  }

  Future<List<Map<String, dynamic>>> _fetchFallbackPostRows({
    required Set<String> excludePostIds,
    required SearchSortMode sortMode,
    required int limit,
  }) async {
    final query = SupabaseService.client
        .from('Post')
        .select(_postSearchSelect)
        .eq('isPending', false)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('Restaurant.isDisabled', false);

    if (excludePostIds.isNotEmpty) {
      query.not(
        'post_Id',
        'in',
        '(${excludePostIds.map((id) => '"$id"').join(',')})',
      );
    }

    final rows = await query.limit(limit);
    final mapped = (rows as List<dynamic>)
        .map((row) => row as Map<String, dynamic>)
        .toList();

    return mapped;
  }

  List<PostSearchResult> _rankFallbackPosts(
    List<Map<String, dynamic>> rows, {
    required SearchSortMode sortMode,
    required _PostInteractionProfile interactionProfile,
    double? userLatitude,
    double? userLongitude,
  }) {
    final ranked = rows.map((row) {
      final post = PostModel.fromJson(row);
      final engagementRaw = post.likes + (post.saveCount * 2);
      final engagementScore = min(60.0, log(1 + engagementRaw) * 12);

      final ageHours = post.createdAt != null
          ? max(
              0.0,
              DateTime.now().difference(post.createdAt!).inHours.toDouble(),
            )
          : 720.0;
      final freshnessScore = 30.0 / (1 + (ageHours / 24.0));

      final interactionPenalty = _interactionPenalty(
        post.id,
        interactionProfile,
      );
      final distanceKm = _distanceForPost(
        post,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
      final locationBoost = sortMode == SearchSortMode.top
          ? _locationBoostForSearch(distanceKm)
          : 0.0;

      final totalScore =
          engagementScore + freshnessScore + locationBoost - interactionPenalty;

      return PostSearchResult(
        post: post,
        bucket: PostMatchBucket.p6,
        boostedByRestaurantMatch: false,
        exactScore: 0,
        relevanceScore: 0,
        engagementScore: engagementScore,
        freshnessScore: freshnessScore,
        totalScore: totalScore,
        distanceKm: distanceKm,
      );
    }).toList();

    ranked.sort((a, b) {
      if (sortMode == SearchSortMode.nearby) {
        final distanceCompare = _compareDistanceAsc(a.distanceKm, b.distanceKm);
        if (distanceCompare != 0) return distanceCompare;
      }

      if (sortMode == SearchSortMode.latest) {
        final createdA = a.post.createdAt;
        final createdB = b.post.createdAt;
        if (createdA == null && createdB == null) return 0;
        if (createdA == null) return 1;
        if (createdB == null) return -1;
        return createdB.compareTo(createdA);
      }

      final totalCompare = b.totalScore.compareTo(a.totalScore);
      if (totalCompare != 0) return totalCompare;

      final createdA = a.post.createdAt;
      final createdB = b.post.createdAt;
      if (createdA == null && createdB == null) return 0;
      if (createdA == null) return 1;
      if (createdB == null) return -1;
      return createdB.compareTo(createdA);
    });

    return ranked;
  }

  bool _shouldShowRestaurantPreview(
    List<RestaurantSearchResult> restaurants,
    List<String> tokens,
  ) {
    if (restaurants.isEmpty) return false;

    // Always show when there is at least one high-confidence entity/place match.
    if (restaurants.any(
      (r) =>
          r.bucket == RestaurantMatchBucket.r1 ||
          r.bucket == RestaurantMatchBucket.r2 ||
          r.bucket == RestaurantMatchBucket.r3,
    )) {
      return true;
    }

    // Fuzzy-only previews stay conservative, especially for broad one-token queries.
    if (restaurants.any((r) => r.bucket == RestaurantMatchBucket.r4)) {
      return tokens.length >= 2;
    }

    return false;
  }

  int _restaurantBucketPriority(RestaurantMatchBucket bucket) {
    return switch (bucket) {
      RestaurantMatchBucket.r1 => 4,
      RestaurantMatchBucket.r2 => 3,
      RestaurantMatchBucket.r3 => 2,
      RestaurantMatchBucket.r4 => 1,
      RestaurantMatchBucket.none => 0,
    };
  }

  int _postBucketPriority(PostMatchBucket bucket) {
    return switch (bucket) {
      PostMatchBucket.p1 => 6,
      PostMatchBucket.p2 => 5,
      PostMatchBucket.p3 => 4,
      PostMatchBucket.p4 => 3,
      PostMatchBucket.p5 => 2,
      PostMatchBucket.p6 => 1,
      PostMatchBucket.irrelevant => 0,
    };
  }

  double? _distanceForRestaurant(
    RestaurantModel restaurant, {
    double? userLatitude,
    double? userLongitude,
  }) {
    if (userLatitude == null ||
        userLongitude == null ||
        restaurant.latitude == null ||
        restaurant.longitude == null) {
      return null;
    }

    return _calculateDistanceKm(
      userLatitude,
      userLongitude,
      restaurant.latitude!,
      restaurant.longitude!,
    );
  }

  double? _distanceForPost(
    PostModel post, {
    double? userLatitude,
    double? userLongitude,
  }) {
    if (userLatitude == null ||
        userLongitude == null ||
        post.restaurantLatitude == null ||
        post.restaurantLongitude == null) {
      return null;
    }

    return _calculateDistanceKm(
      userLatitude,
      userLongitude,
      post.restaurantLatitude!,
      post.restaurantLongitude!,
    );
  }

  int _compareDistanceAsc(double? a, double? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  double _locationBoostForSearch(double? distanceKm) {
    if (distanceKm == null) return 0.0;
    if (distanceKm <= 3) return 25.0;
    if (distanceKm <= 8) return 15.0;
    if (distanceKm <= 15) return 8.0;
    return 0.0;
  }

  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  double _postTokenRelevance({
    required List<String> tokens,
    required Set<String> titleWords,
    required Set<String> captionWords,
    required Set<String> restaurantNameWords,
    required Set<String> restaurantAddressWords,
  }) {
    if (tokens.isEmpty) return 0;

    double score = 0;
    int matchedCount = 0;

    for (final token in tokens) {
      final inTitle = titleWords.contains(token);
      final inCaption = captionWords.contains(token);
      final inRestaurantName = restaurantNameWords.contains(token);
      final inRestaurantAddress = restaurantAddressWords.contains(token);

      double tokenScore = 0;
      if (inTitle) {
        tokenScore = 3.0;
      } else if (inCaption) {
        tokenScore = 2.0;
      } else if (inRestaurantName) {
        tokenScore = 1.5;
      } else if (inRestaurantAddress) {
        tokenScore = 1.0;
      }

      if (tokenScore > 0) {
        matchedCount += 1;
        score += tokenScore;
      }
    }

    final coverage = matchedCount / tokens.length;
    return score + (coverage * 3.0);
  }

  double _trendingScore(PostModel post) {
    final engagement = post.likes + (post.saveCount * 2);

    final ageHours = post.createdAt != null
        ? max(
            0.0,
            DateTime.now().difference(post.createdAt!).inHours.toDouble(),
          )
        : 720.0;

    final freshnessBoost = 30.0 / (1 + (ageHours / 24.0));
    return engagement + freshnessBoost;
  }

  String? _cleanTrendingTitle(String raw) {
    final normalized = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('\n', ' ')
        .trim();

    if (normalized.isEmpty) return null;
    if (normalized.length < 4) return null;

    final hasAlphaNumeric = RegExp(r'[a-zA-Z0-9]').hasMatch(normalized);
    if (!hasAlphaNumeric) return null;

    final lowered = normalized.toLowerCase();
    const badValues = {'test', 'lol', '...', '???', 'hi'};
    if (badValues.contains(lowered)) return null;

    if (normalized.length > 45) {
      final shortened = normalized.substring(0, 42).trimRight();
      return '$shortened...';
    }

    return normalized;
  }

  String _toSafeIlikeInput(String value) {
    return value
        .trim()
        .replaceAll('%', ' ')
        .replaceAll('_', ' ')
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeText(String value) {
    final lower = value.toLowerCase().trim();
    final withoutPunctuation = lower.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return withoutPunctuation.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _normalizedHashtagIntentFromQuery(String rawQuery) {
    final trimmed = rawQuery.trim();
    if (!trimmed.startsWith('#')) return null;

    final withoutHash = trimmed.substring(1);
    if (withoutHash.isEmpty) return null;

    final token = _normalizeText(withoutHash).split(' ').first;
    if (token.length < 2) return null;
    return token;
  }

  SearchSuggestion? _buildHashtagSuggestion(String normalizedQuery) {
    if (normalizedQuery.isEmpty || normalizedQuery.length < 2) return null;
    if (normalizedQuery.contains(' ')) return null;

    final hashtag = '#$normalizedQuery';
    return SearchSuggestion(
      type: SearchSuggestionType.hashtag,
      displayText: hashtag,
      queryText: hashtag,
    );
  }

  bool _postHasExactHashtag(PostModel post, String hashtag) {
    final normalizedHashtag = _normalizeText(hashtag);
    if (normalizedHashtag.isEmpty) return false;

    for (final tag in post.hashtags) {
      if (_normalizeText(tag) == normalizedHashtag) {
        return true;
      }
    }

    final extracted = _extractHashtagsFromText(
      '${post.title} ${post.description}',
    );
    return extracted.contains(normalizedHashtag);
  }

  Set<String> _extractHashtagsFromText(String text) {
    final matches = RegExp(r'#([A-Za-z0-9_]+)').allMatches(text);
    final tags = <String>{};
    for (final match in matches) {
      final tag = match.group(1);
      if (tag == null || tag.isEmpty) continue;
      tags.add(_normalizeText(tag));
    }
    return tags;
  }

  List<String> _tokenize(String normalized) {
    if (normalized.isEmpty) return const [];
    return normalized
        .split(' ')
        .where((t) => t.length >= 2)
        .toList(growable: false);
  }

  Set<String> _wordSet(String normalized) {
    if (normalized.isEmpty) return const {};
    return normalized.split(' ').where((w) => w.isNotEmpty).toSet();
  }

  int _matchedTokenCount(List<String> queryTokens, Set<String> fieldWords) {
    var count = 0;
    for (final token in queryTokens) {
      if (fieldWords.contains(token)) {
        count += 1;
      }
    }
    return count;
  }

  double _tokenOverlapRatio(List<String> queryTokens, Set<String> fieldWords) {
    if (queryTokens.isEmpty || fieldWords.isEmpty) return 0;
    final matched = _matchedTokenCount(queryTokens, fieldWords);
    return matched / queryTokens.length;
  }

  double _fuzzySimilarity(String query, String text) {
    if (query.isEmpty || text.isEmpty) return 0;
    final queryWords = _wordSet(query).toList();
    final textWords = _wordSet(text).toList();
    if (queryWords.isEmpty || textWords.isEmpty) return 0;

    double best = 0;
    for (final qWord in queryWords) {
      for (final tWord in textWords) {
        final score = _pairSimilarity(qWord, tWord);
        if (score > best) best = score;
      }
    }

    // Also compare with full text for phrase-ish typo support.
    best = max(best, _pairSimilarity(query, text));
    return best;
  }

  double _pairSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final distance = _levenshtein(a, b);
    final maxLen = max(a.length, b.length);
    return 1.0 - (distance / maxLen);
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final v0 = List<int>.generate(b.length + 1, (i) => i);
    final v1 = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      v1[0] = i + 1;

      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        v1[j + 1] = min(min(v1[j] + 1, v0[j + 1] + 1), v0[j] + cost);
      }

      for (var j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v0[b.length];
  }

  Future<_PostInteractionProfile> _buildPostInteractionProfile(
    String userId,
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return const _PostInteractionProfile.empty();

    final likedPostIds = <String>{};
    final savedPostIds = <String>{};
    final commentedPostIds = <String>{};

    final likesResponse = await SupabaseService.client
        .from('Likes')
        .select('post_Id')
        .eq('user_Id', userId)
        .inFilter('post_Id', postIds);
    for (final row in likesResponse as List<dynamic>) {
      final id = (row as Map<String, dynamic>)['post_Id']?.toString();
      if (id != null) likedPostIds.add(id);
    }

    final savesResponse = await SupabaseService.client
        .from('collections_item')
        .select('post_id, collections!inner(user_Id, collection_type)')
        .eq('collections.user_Id', userId)
        .eq('collections.collection_type', 'POST')
        .not('post_id', 'is', null)
        .inFilter('post_id', postIds);
    for (final row in savesResponse as List<dynamic>) {
      final id = (row as Map<String, dynamic>)['post_id']?.toString();
      if (id != null) savedPostIds.add(id);
    }

    final commentsResponse = await SupabaseService.client
        .from('Comment')
        .select('post_Id')
        .eq('user_Id', userId)
        .inFilter('post_Id', postIds);
    for (final row in commentsResponse as List<dynamic>) {
      final id = (row as Map<String, dynamic>)['post_Id']?.toString();
      if (id != null) commentedPostIds.add(id);
    }

    return _PostInteractionProfile(
      likedPostIds: likedPostIds,
      savedPostIds: savedPostIds,
      commentedPostIds: commentedPostIds,
    );
  }

  double _interactionPenalty(String postId, _PostInteractionProfile profile) {
    double penalty = 0.0;
    if (profile.likedPostIds.contains(postId)) penalty += 10.0;
    if (profile.savedPostIds.contains(postId)) penalty += 15.0;
    if (profile.commentedPostIds.contains(postId)) penalty += 10.0;
    return penalty > 25.0 ? 25.0 : penalty;
  }
}

class _PostInteractionProfile {
  final Set<String> likedPostIds;
  final Set<String> savedPostIds;
  final Set<String> commentedPostIds;

  const _PostInteractionProfile({
    required this.likedPostIds,
    required this.savedPostIds,
    required this.commentedPostIds,
  });

  const _PostInteractionProfile.empty()
    : likedPostIds = const {},
      savedPostIds = const {},
      commentedPostIds = const {};
}
