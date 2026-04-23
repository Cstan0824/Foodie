import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/hashtag_model.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/repositories/repository_support.dart';

/// Handles all search-related queries across posts, restaurants, cuisines,
/// and hashtags. Rule-based only — no AI/ML scoring.
class SearchRepository {
  SearchRepository._();
  static final SearchRepository instance = SearchRepository._();

  // ---------------------------------------------------------------------------
  // 1. Post Text Search
  // ---------------------------------------------------------------------------

  /// Searches posts by matching keyword against title and caption.
  /// Results ordered by newest first.
  Future<List<PostModel>> searchPosts(
    String query, {
    int limit = 30,
    int offset = 0,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final response = await SupabaseService.client
        .from('Post')
        .select(publicPostSelect)
        .eq('isRemoved', false)
        .eq('isBlocked', false)
        .eq('isPending', false)
        .or('title.ilike.%$q%,caption.ilike.%$q%')
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 2. Restaurant-linked Search
  // ---------------------------------------------------------------------------

  /// Finds restaurants matching the keyword (name or address),
  /// then returns visible posts linked to those restaurants.
  Future<List<PostModel>> searchPostsByRestaurant(
    String query, {
    int limit = 30,
    int offset = 0,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Step 1: find matching restaurant IDs
    final restaurants = await SupabaseService.client
        .from('Restaurant')
        .select('restaurant_Id')
        .eq('isDisabled', false)
        .or('restaurant_name.ilike.%$q%,address.ilike.%$q%')
        .limit(50);

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
  // 3. Cuisine-based Search
  // ---------------------------------------------------------------------------

  /// Returns posts linked to restaurants that have the given cuisine —
  /// either as their main cuisine or as an extra tag in Restaurant_Cuisine.
  Future<List<PostModel>> searchPostsByCuisine(
    String cuisineId, {
    int limit = 30,
    int offset = 0,
  }) async {
    if (cuisineId.trim().isEmpty) return [];

    // Restaurants where this is the main cuisine
    final mainRows = await SupabaseService.client
        .from('Restaurant')
        .select('restaurant_Id')
        .eq('isDisabled', false)
        .eq('main_cuisine_id', cuisineId);

    // Restaurants where this is an extra tag
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
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => PostModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 4. Hashtag Search
  // ---------------------------------------------------------------------------

  /// Finds posts tagged with a hashtag whose name contains [hashtag].
  /// Uses partial match so searching "food" also finds "#foodie".
  Future<List<PostModel>> searchPostsByHashtag(
    String hashtag, {
    int limit = 30,
    int offset = 0,
  }) async {
    final q = hashtag.trim().replaceAll('#', '');
    if (q.isEmpty) return [];

    // Step 1: find matching hashtag IDs
    final hashtags = await SupabaseService.client
        .from('hashtag')
        .select('hashtag_id')
        .ilike('name', '%$q%')
        .limit(20);

    final hashtagIds = (hashtags as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['hashtag_id']?.toString())
        .whereType<String>()
        .toList();

    if (hashtagIds.isEmpty) return [];

    // Step 2: find post IDs linked to those hashtags
    final postHashtags = await SupabaseService.client
        .from('post_hashtag')
        .select('post_Id')
        .inFilter('hashtag_id', hashtagIds);

    final postIds = (postHashtags as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['post_Id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    if (postIds.isEmpty) return [];

    // Step 3: fetch those posts
    final response = await SupabaseService.client
        .from('Post')
        .select(publicPostSelect)
        .inFilter('post_Id', postIds)
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
  // 5. Combined Search
  // ---------------------------------------------------------------------------

  /// Runs post text search + restaurant name search in parallel,
  /// merges results, deduplicates, and ranks by engagement + freshness.
  Future<List<PostModel>> searchAll(
    String query, {
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) return [];

    // Run both searches concurrently (each fetches extra to allow dedup)
    final results = await Future.wait([
      searchPosts(query, limit: limit),
      searchPostsByRestaurant(query, limit: limit),
    ]);

    // Merge and deduplicate by post ID
    final seen = <String>{};
    final merged = <PostModel>[];
    for (final list in results) {
      for (final post in list) {
        if (seen.add(post.id)) {
          merged.add(post);
        }
      }
    }

    // Rank by relevance: engagement + freshness
    merged.sort((a, b) => _relevanceScore(b).compareTo(_relevanceScore(a)));

    return merged.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // 6. Trending Hashtags
  // ---------------------------------------------------------------------------

  /// Returns the most-used hashtags based on recent post-hashtag links.
  /// Counts occurrences client-side — practical for small-to-medium datasets.
  /// For production scale, consider an RPC function or database view.
  Future<List<HashtagModel>> fetchTrendingHashtags({int limit = 10}) async {
    // Fetch a batch of recent post_hashtag rows with hashtag details
    final response = await SupabaseService.client
        .from('post_hashtag')
        .select('hashtag_id, hashtag(hashtag_id, name)')
        .limit(500);

    // Count occurrences per hashtag
    final counts = <String, _TagCount>{};
    for (final row in (response as List<dynamic>)) {
      final ht = (row as Map<String, dynamic>)['hashtag'];
      if (ht == null) continue;
      final htMap = ht as Map<String, dynamic>;
      final id = htMap['hashtag_id']?.toString() ?? '';
      final name = htMap['name']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty) continue;

      counts[id] = _TagCount(id, name, (counts[id]?.count ?? 0) + 1);
    }

    // Sort by count descending and return top N
    final sorted = counts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return sorted
        .take(limit)
        .map((t) => HashtagModel(id: t.id, name: t.name))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Simple relevance score: engagement + time-decay freshness boost.
  double _relevanceScore(PostModel post) {
    final engagement = post.likes + (post.saveCount * 2);
    final ageHours = post.createdAt != null
        ? DateTime.now().difference(post.createdAt!).inHours.toDouble()
        : 720.0; // assume 30 days old if unknown
    final freshness = 1000.0 / (1.0 + ageHours);
    return engagement + freshness;
  }
}

/// Internal helper for hashtag counting.
class _TagCount {
  final String id;
  final String name;
  final int count;
  const _TagCount(this.id, this.name, this.count);
}
