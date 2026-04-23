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

  /// Fetches discover feed posts ranked by engagement + freshness.
  ///
  /// Unlike [PostRepository.fetchDiscoverPosts] which simply orders by date,
  /// this fetches a larger batch and re-ranks client-side using a weighted
  /// score of likes, saves, and recency.
  Future<List<PostModel>> fetchDiscoverFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    // Fetch a larger pool to allow meaningful ranking
    final poolSize = limit * 3;

    final response = await SupabaseService.client
        .from('Post')
        .select(publicPostSelect)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .order('created_At', ascending: false)
        .range(offset, offset + poolSize - 1);

    final posts = (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();

    // Rank by engagement + freshness
    posts.sort((a, b) => _relevanceScore(b).compareTo(_relevanceScore(a)));

    return posts.take(limit).toList();
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

  /// Relevance score: engagement weighted + time-decay freshness boost.
  /// Same formula as SearchRepository for consistency across the app.
  double _relevanceScore(PostModel post) {
    final engagement = post.likes + (post.saveCount * 2);
    final ageHours = post.createdAt != null
        ? DateTime.now().difference(post.createdAt!).inHours.toDouble()
        : 720.0;
    final freshness = 1000.0 / (1.0 + ageHours);
    return engagement + freshness;
  }

  /// Approximate cosine for longitude scaling in bounding-box calculation.
  double _cosApprox(double degrees) {
    final rad = degrees * 3.14159265 / 180.0;
    // Taylor approximation good enough for bounding box
    return 1.0 - (rad * rad / 2.0);
  }
}
