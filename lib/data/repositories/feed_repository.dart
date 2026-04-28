import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/repositories/repository_support.dart';

/// Home feed logic — ranking, filtering, and ordering posts for display.
///
/// This is separate from [PostRepository] which handles raw CRUD.
/// FeedRepository adds engagement-weighted scoring, location filtering,
/// and cuisine-based feeds. All rule-based, no AI.
class FeedRepository {
  FeedRepository._();
  static final FeedRepository instance = FeedRepository._();

  // ---------------------------------------------------------------------------
  // 1. Discover Feed (Ranked)
  // ---------------------------------------------------------------------------

  /// Fetches discover feed posts ranked by engagement + freshness, with optional personalization.
  Future<List<PostModel>> fetchDiscoverFeed({
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final normalizedUserId = userId?.trim();
    // Fetch a larger pool to allow meaningful ranking and diversity reranking.
    final poolSize = limit * 4;

    final response = await SupabaseService.client
        .from('Post')
        .select(getPostSelectWithStatus(normalizedUserId))
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .order('created_At', ascending: false)
        .range(offset, offset + poolSize - 1);

    final rows = (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (rows.isEmpty) return [];

    final preferences = normalizedUserId == null || normalizedUserId.isEmpty
        ? const _FeedPreferenceProfile.empty()
        : await _buildPreferenceProfile(normalizedUserId);

    final postIds = rows.map((r) => r['post_Id']?.toString()).whereType<String>().toList();
    final interactionProfile = normalizedUserId == null || normalizedUserId.isEmpty || postIds.isEmpty
        ? const _PostInteractionProfile.empty()
        : await _buildPostInteractionProfile(normalizedUserId, postIds);

    final rankedRows =
        rows
            .map(
              (row) => _RankedPostRow(
                row: row,
                score: _personalizedRowScore(row, preferences, interactionProfile),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final diversifiedRows = _diversifyRankedRows(rankedRows, limit: limit);

    final posts = diversifiedRows
        .map((ranked) => PostModel.fromJson(ranked.row))
        .toList();

    return _applyViewerLikeState(posts, normalizedUserId);
  }

  Future<List<PostModel>> _applyViewerLikeState(
    List<PostModel> posts,
    String? viewerUserId,
  ) async {
    if (posts.isEmpty) return posts;
    if (viewerUserId == null || viewerUserId.isEmpty) {
      return posts.map((post) => post.copyWith(isLiked: false)).toList();
    }

    final postIds = posts.map((post) => post.id).toList();
    final likesResponse = await SupabaseService.client
        .from('Likes')
        .select('post_Id')
        .eq('user_Id', viewerUserId)
        .inFilter('post_Id', postIds);

    final likedIds = (likesResponse as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['post_Id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    return posts
        .map((post) => post.copyWith(isLiked: likedIds.contains(post.id)))
        .toList();
  }
  // ---------------------------------------------------------------------------
  // 5. Preference Profile
  // ---------------------------------------------------------------------------

  /// Builds a lightweight, rule-based preference profile from the user's saved
  /// restaurant and post collections.
  ///
  /// Signals used:
  /// - saved restaurants: strong restaurant + cuisine preference
  /// - saved posts: medium restaurant + cuisine preference through linked posts
  Future<_FeedPreferenceProfile> _buildPreferenceProfile(String userId) async {
    final savedRestaurantIds = <String>{};
    final restaurantCuisineWeights = <String, double>{};

    // Saved restaurant collections.
    final savedRestaurantRows = await SupabaseService.client
        .from('collections_item')
        .select('restaurant_id, collections!inner(user_Id, collection_type)')
        .eq('collections.user_Id', userId)
        .eq('collections.collection_type', 'RESTAURANT')
        .not('restaurant_id', 'is', null);

    for (final row in savedRestaurantRows as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      final restaurantId = map['restaurant_id']?.toString();
      if (restaurantId != null && restaurantId.isNotEmpty) {
        savedRestaurantIds.add(restaurantId);
      }
    }

    if (savedRestaurantIds.isNotEmpty) {
      final restaurantRows = await SupabaseService.client
          .from('Restaurant')
          .select('restaurant_Id, main_cuisine_id')
          .inFilter('restaurant_Id', savedRestaurantIds.toList());

      for (final row in restaurantRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final cuisineId = map['main_cuisine_id']?.toString();
        if (cuisineId != null && cuisineId.isNotEmpty) {
          restaurantCuisineWeights[cuisineId] =
              (restaurantCuisineWeights[cuisineId] ?? 0) + 5.0;
        }
      }
    }

    // Saved post collections.
    final savedPostIds = <String>{};
    final savedPostRows = await SupabaseService.client
        .from('collections_item')
        .select('post_id, collections!inner(user_Id, collection_type)')
        .eq('collections.user_Id', userId)
        .eq('collections.collection_type', 'POST')
        .not('post_id', 'is', null);

    for (final row in savedPostRows as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      final postId = map['post_id']?.toString();
      if (postId != null && postId.isNotEmpty) {
        savedPostIds.add(postId);
      }
    }

    if (savedPostIds.isNotEmpty) {
      final savedPosts = await SupabaseService.client
          .from('Post')
          .select('post_Id, restaurant_Id, Restaurant(main_cuisine_id)')
          .inFilter('post_Id', savedPostIds.toList());

      for (final row in savedPosts as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final restaurantId = map['restaurant_Id']?.toString();
        if (restaurantId != null && restaurantId.isNotEmpty) {
          savedRestaurantIds.add(restaurantId);
        }

        final restaurant = map['Restaurant'];
        if (restaurant is Map<String, dynamic>) {
          final cuisineId = restaurant['main_cuisine_id']?.toString();
          if (cuisineId != null && cuisineId.isNotEmpty) {
            restaurantCuisineWeights[cuisineId] =
                (restaurantCuisineWeights[cuisineId] ?? 0) + 3.0;
          }
        }
      }
    }

    return _FeedPreferenceProfile(
      savedRestaurantIds: savedRestaurantIds,
      cuisineWeights: restaurantCuisineWeights,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Following Feed
  // ---------------------------------------------------------------------------

  /// Posts from accounts the user follows, ranked by engagement + freshness.
  Future<List<PostModel>> fetchFollowingFeed({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    // Step 1: get followed user IDs
    final followingRows = await SupabaseService.client
        .from('Follower')
        .select('following_Id')
        .eq('follower_Id', userId);

    final followingIds = (followingRows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['following_Id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (followingIds.isEmpty) return [];

    // Step 2: fetch their posts
    final poolSize = limit * 2;

    final response = await SupabaseService.client
        .from('Post')
        .select(publicPostSelect)
        .inFilter('user_Id', followingIds)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .order('created_At', ascending: false)
        .range(offset, offset + poolSize - 1);

    final posts = (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();

    posts.sort((a, b) => _relevanceScore(b).compareTo(_relevanceScore(a)));

    return posts.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // 3. Nearby Feed
  // ---------------------------------------------------------------------------

  /// Posts linked to restaurants within [radiusKm] of the given coordinates.
  ///
  /// Uses a bounding-box approximation (not Haversine) for simplicity.
  /// Restaurants without coordinates are excluded.
  Future<List<PostModel>> fetchNearbyFeed({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int limit = 20,
    int offset = 0,
  }) async {
    // Rough bounding box: 1 degree latitude ≈ 111 km
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm / (111.0 * _cosApprox(latitude));

    final minLat = latitude - latDelta;
    final maxLat = latitude + latDelta;
    final minLng = longitude - lngDelta;
    final maxLng = longitude + lngDelta;

    // Step 1: find nearby restaurant IDs
    final restaurants = await SupabaseService.client
        .from('Restaurant')
        .select('restaurant_Id')
        .eq('isDisabled', false)
        .gte('latitude', minLat)
        .lte('latitude', maxLat)
        .gte('longitude', minLng)
        .lte('longitude', maxLng)
        .limit(100);

    final ids = (restaurants as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['restaurant_Id']?.toString())
        .whereType<String>()
        .toList();

    if (ids.isEmpty) return [];

    // Step 2: fetch posts for those restaurants
    final response = await SupabaseService.client
        .from('Post')
        .select(publicPostSelect)
        .inFilter('restaurant_Id', ids)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 4. Cuisine Feed
  // ---------------------------------------------------------------------------

  /// Posts linked to restaurants with the given cuisine type
  /// (main cuisine or extra tag), ranked by engagement.
  Future<List<PostModel>> fetchFeedByCuisine({
    required String cuisineId,
    int limit = 20,
    int offset = 0,
  }) async {
    // Restaurants with this cuisine as main
    final mainRows = await SupabaseService.client
        .from('Restaurant')
        .select('restaurant_Id')
        .eq('isDisabled', false)
        .eq('main_cuisine_id', cuisineId);

    // Restaurants with this cuisine as extra tag
    final tagRows = await SupabaseService.client
        .from('Restaurant_Cuisine')
        .select('RestaurantId')
        .eq('CuisineId', cuisineId);

    final allIds = <String>{
      ...(mainRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['restaurant_Id']?.toString())
          .whereType<String>(),
      ...(tagRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['RestaurantId']?.toString())
          .whereType<String>(),
    };

    if (allIds.isEmpty) return [];

    final response = await SupabaseService.client
        .from('Post')
        .select(publicPostSelect)
        .inFilter('restaurant_Id', allIds.toList())
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .order('created_At', ascending: false)
        .range(offset, offset + (limit * 2) - 1);

    final posts = (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();

    posts.sort((a, b) => _relevanceScore(b).compareTo(_relevanceScore(a)));

    return posts.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<_PostInteractionProfile> _buildPostInteractionProfile(
    String userId,
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return const _PostInteractionProfile.empty();

    final likedPostIds = <String>{};
    final savedPostIds = <String>{};
    final commentedPostIds = <String>{};

    // Liked posts
    final likesResponse = await SupabaseService.client
        .from('Likes')
        .select('post_Id')
        .eq('user_Id', userId)
        .inFilter('post_Id', postIds);
    for (final row in likesResponse as List<dynamic>) {
      final id = (row as Map<String, dynamic>)['post_Id']?.toString();
      if (id != null) likedPostIds.add(id);
    }

    // Saved posts
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

    // Commented posts
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
    if (profile.likedPostIds.contains(postId)) penalty += 40.0;
    if (profile.savedPostIds.contains(postId)) penalty += 70.0;
    if (profile.commentedPostIds.contains(postId)) penalty += 60.0;
    return penalty > 120.0 ? 120.0 : penalty;
  }

  /// Legacy generic relevance score used by non-personalized feeds.
  /// Engagement weighted + time-decay freshness boost.
  double _relevanceScore(PostModel post) {
    final engagement = post.likes + (post.saveCount * 2);
    final ageHours = post.createdAt != null
        ? DateTime.now().difference(post.createdAt!).inHours.toDouble()
        : 720.0;
    final freshness = 1000.0 / (1.0 + ageHours);
    return engagement + freshness;
  }

  /// Personalized score for home discover feed.
  /// Ranking priority:
  /// 1. saved restaurant / cuisine preference
  /// 2. engagement
  /// 3. freshness
  double _personalizedRowScore(
    Map<String, dynamic> row,
    _FeedPreferenceProfile preferences,
    _PostInteractionProfile interactionProfile,
  ) {
    final restaurantId = _readRestaurantId(row);
    final cuisineId = _readRestaurantCuisineId(row);

    final restaurantPreferenceScore =
        restaurantId != null &&
            preferences.savedRestaurantIds.contains(restaurantId)
        ? 100.0
        : 0.0;

    final rawCuisineWeight = cuisineId == null
        ? 0.0
        : preferences.cuisineWeights[cuisineId] ?? 0.0;
    final cuisinePreferenceScore = (rawCuisineWeight * 20.0).clamp(0.0, 120.0);

    final likes = _readInt(row['likeCount']);
    final saves = _readInt(row['saveCount']);
    final engagementScore = (likes + (saves * 3)).clamp(0, 120).toDouble();

    final createdAt = _readDateTime(row['created_At']);
    final ageHours = createdAt == null
        ? 720.0
        : DateTime.now().difference(createdAt).inHours.toDouble();
    final freshnessScore = 100.0 / (1.0 + (ageHours / 6.0));

    final postId = row['post_Id']?.toString();
    final interactionPenalty = postId != null ? _interactionPenalty(postId, interactionProfile) : 0.0;

    return restaurantPreferenceScore +
        cuisinePreferenceScore +
        engagementScore +
        freshnessScore -
        interactionPenalty;
  }

  /// Applies a simple diversity pass so the top feed does not become too
  /// repetitive when a user has strong preferences.
  List<_RankedPostRow> _diversifyRankedRows(
    List<_RankedPostRow> rankedRows, {
    required int limit,
  }) {
    final selected = <_RankedPostRow>[];
    final deferred = <_RankedPostRow>[];
    final restaurantCounts = <String, int>{};
    final cuisineCounts = <String, int>{};

    for (final ranked in rankedRows) {
      final restaurantId = _readRestaurantId(ranked.row);
      final cuisineId = _readRestaurantCuisineId(ranked.row);

      final restaurantCount = restaurantId == null
          ? 0
          : restaurantCounts[restaurantId] ?? 0;
      final cuisineCount = cuisineId == null
          ? 0
          : cuisineCounts[cuisineId] ?? 0;

      final wouldRepeatTooMuch = restaurantCount >= 2 || cuisineCount >= 4;

      if (wouldRepeatTooMuch && selected.length < limit) {
        deferred.add(ranked);
        continue;
      }

      selected.add(ranked);
      if (restaurantId != null) {
        restaurantCounts[restaurantId] = restaurantCount + 1;
      }
      if (cuisineId != null) {
        cuisineCounts[cuisineId] = cuisineCount + 1;
      }

      if (selected.length >= limit) break;
    }

    if (selected.length < limit) {
      for (final ranked in deferred) {
        selected.add(ranked);
        if (selected.length >= limit) break;
      }
    }

    return selected.take(limit).toList();
  }

  String? _readRestaurantId(Map<String, dynamic> row) {
    return row['restaurant_Id']?.toString() ?? row['restaurant_id']?.toString();
  }

  String? _readRestaurantCuisineId(Map<String, dynamic> row) {
    final restaurant = row['Restaurant'];
    if (restaurant is Map<String, dynamic>) {
      return restaurant['main_cuisine_id']?.toString();
    }
    return row['main_cuisine_id']?.toString();
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _readDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Approximate cosine for longitude scaling in bounding-box calculation.
  double _cosApprox(double degrees) {
    final rad = degrees * 3.14159265 / 180.0;
    // Taylor approximation good enough for bounding box
    return 1.0 - (rad * rad / 2.0);
  }
}

class _FeedPreferenceProfile {
  final Set<String> savedRestaurantIds;
  final Map<String, double> cuisineWeights;

  const _FeedPreferenceProfile({
    required this.savedRestaurantIds,
    required this.cuisineWeights,
  });

  const _FeedPreferenceProfile.empty()
    : savedRestaurantIds = const {},
      cuisineWeights = const {};
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

class _RankedPostRow {
  final Map<String, dynamic> row;
  final double score;

  const _RankedPostRow({required this.row, required this.score});
}
