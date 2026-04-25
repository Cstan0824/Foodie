import 'dart:math';

import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';
import 'package:taste_spot/data/models/swipe_history_model.dart';

/// Handles BlindBox restaurant recommendation, swipe tracking,
/// and restaurant saving. System-driven, rule-based — no AI.
class BlindBoxRepository {
  BlindBoxRepository._();
  static final BlindBoxRepository instance = BlindBoxRepository._();

  /// Select columns for restaurant cards in BlindBox.
  static const String _cardSelect = '''
    restaurant_Id,
    restaurant_name,
    description,
    price_range,
    address,
    latitude,
    longitude,
    maps_url,
    main_cuisine_id,
    source,
    info_url,
    isDisabled,
    rating,
    created_At,
    mainCuisine:Cuisine!restaurant_main_cuisine_fk(type_id, desc, isPrimaryOption),
    Restaurant_Image(image_id, image_url, isCover)
  ''';

  // ---------------------------------------------------------------------------
  // 1. Recommendations
  // ---------------------------------------------------------------------------

  /// Fetches restaurant recommendations for the BlindBox swipe deck.
  ///
  /// Logic:
  /// 1. Fetches active candidates (with valid coordinates).
  /// 2. Infers user preferences from their saved RESTAURANT collections.
  /// 3. Computes a score based on Location (strongest), Preference (medium), and Newness (smallest).
  /// 4. Groups results into Tiers, shuffles within each tier, and concatenates.
  ///
  /// Note: Previously swiped restaurants are NOT excluded. They remain eligible.
  /// [cuisineId] is no longer a strict filter, but provides a preference boost if provided.
  Future<List<RestaurantModel>> fetchRecommendations({
    required String userId,
    String? cuisineId,
    double? userLatitude,
    double? userLongitude,
    int limit = 20,
  }) async {
    // 1. Fetch eligible candidates
    final response = await SupabaseService.client
        .from('Restaurant')
        .select(_cardSelect)
        .eq('isDisabled', false)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .limit(500); // large enough candidate pool for ranking

    final List<Map<String, dynamic>> candidatesData = (response as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    if (candidatesData.isEmpty) return [];

    // 2. Infer User Preferences from saved RESTAURANT collections
    Set<String> preferredMainCuisines = {};
    Set<String> preferredExtraCuisines = {};

    final collections = await SupabaseService.client
        .from('collections')
        .select('collection_Id')
        .eq('user_Id', userId)
        .eq('collection_type', 'RESTAURANT');

    final collectionIds = (collections as List<dynamic>)
        .map((r) => r['collection_Id']?.toString())
        .whereType<String>()
        .toList();

    if (collectionIds.isNotEmpty) {
      final itemsResponse = await SupabaseService.client
          .from('collections_item')
          .select('restaurant_id')
          .inFilter('collection_Id', collectionIds)
          .not('restaurant_id', 'is', null);

      final savedIds = (itemsResponse as List<dynamic>)
          .map((e) => e['restaurant_id']?.toString())
          .whereType<String>()
          .toList();

      if (savedIds.isNotEmpty) {
        final savedRestaurants = await SupabaseService.client
            .from('Restaurant')
            .select('main_cuisine_id')
            .inFilter('restaurant_Id', savedIds);

        for (var r in savedRestaurants as List<dynamic>) {
          final mc = r['main_cuisine_id']?.toString();
          if (mc != null) preferredMainCuisines.add(mc);
        }

        final extraResponse = await SupabaseService.client
            .from('Restaurant_Cuisine')
            .select('CuisineId')
            .inFilter('RestaurantId', savedIds);

        for (var r in extraResponse as List<dynamic>) {
          final ec = r['CuisineId']?.toString();
          if (ec != null) preferredExtraCuisines.add(ec);
        }
      }
    }

    // Pre-fetch extra cuisines for candidates
    final candidateIds = candidatesData.map((c) => c['restaurant_Id']?.toString()).whereType<String>().toList();
    Map<String, List<String>> candidateExtraCuisines = {};

    if (candidateIds.isNotEmpty) {
      final candidateExtraResp = await SupabaseService.client
          .from('Restaurant_Cuisine')
          .select('RestaurantId, CuisineId')
          .inFilter('RestaurantId', candidateIds);

      for (var row in candidateExtraResp as List<dynamic>) {
        final rId = row['RestaurantId']?.toString();
        final cId = row['CuisineId']?.toString();
        if (rId != null && cId != null) {
          candidateExtraCuisines.putIfAbsent(rId, () => []).add(cId);
        }
      }
    }

    // 3. Compute Scores
    final now = DateTime.now();
    List<Map<String, dynamic>> scoredCandidates = [];

    for (var row in candidatesData) {
      double score = 0;
      final lat = (row['latitude'] as num?)?.toDouble();
      final lng = (row['longitude'] as num?)?.toDouble();
      final mainCuisine = row['main_cuisine_id']?.toString();
      final rId = row['restaurant_Id']?.toString();

      // Priority 1: Location (Strongest)
      if (userLatitude != null && userLongitude != null && lat != null && lng != null) {
        double dist = _calculateDistance(userLatitude, userLongitude, lat, lng);
        if (dist <= 5) {
          score += 50; // Very near
        } else if (dist <= 15) {
          score += 30; // Medium
        } else if (dist <= 50) {
          score += 10; // Far
        }
      }

      // Priority 2: Preference
      if (mainCuisine != null && preferredMainCuisines.contains(mainCuisine)) {
        score += 20;
      }

      if (rId != null) {
        final extras = candidateExtraCuisines[rId] ?? [];
        for (var ex in extras) {
          if (preferredMainCuisines.contains(ex) || preferredExtraCuisines.contains(ex)) {
            score += 5;
          }
        }

        // Apply provided cuisineId as an optional boost, not a strict filter
        if (cuisineId != null && cuisineId.isNotEmpty) {
          if (mainCuisine == cuisineId) {
            score += 15;
          } else if (extras.contains(cuisineId)) {
            score += 5;
          }
        }
      }

      // Priority 3: Newness (Smallest factor)
      final createdAtStr = row['created_At'] as String?;
      if (createdAtStr != null) {
        final createdAt = DateTime.tryParse(createdAtStr);
        if (createdAt != null) {
          final ageInDays = now.difference(createdAt).inDays;
          if (ageInDays <= 7) {
            score += 10;
          } else if (ageInDays <= 30) {
            score += 5;
          }
        }
      }

      scoredCandidates.add({
        'row': row,
        'score': score,
      });
    }

    // 4. Tier-based output
    List<Map<String, dynamic>> tier1 = [];
    List<Map<String, dynamic>> tier2 = [];
    List<Map<String, dynamic>> tier3 = [];

    for (var c in scoredCandidates) {
      final score = c['score'] as double;
      if (score >= 50) {
        tier1.add(c);
      } else if (score >= 20) {
        tier2.add(c);
      } else {
        tier3.add(c);
      }
    }

    final random = Random();
    tier1.shuffle(random);
    tier2.shuffle(random);
    tier3.shuffle(random);

    final finalData = [...tier1, ...tier2, ...tier3]
        .take(limit)
        .map((e) => e['row'] as Map<String, dynamic>);

    return finalData.map((row) => RestaurantModel.fromJson(row)).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers for Recommendation
  // ---------------------------------------------------------------------------

  /// Calculates the distance between two coordinate points in kilometers using Haversine.
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // ---------------------------------------------------------------------------
  // 2. Swipe Tracking
  // ---------------------------------------------------------------------------

  /// Records that the user swiped on (saw) a restaurant.
  Future<void> recordSwipe({
    required String userId,
    required String restaurantId,
  }) async {
    await SupabaseService.client.from('swipe_history').insert({
      'user_id': userId,
      'restaurant_id': restaurantId,
    });
  }

  /// Fetches the user's swipe history, newest first.
  Future<List<SwipeHistoryModel>> fetchSwipeHistory({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await SupabaseService.client
        .from('swipe_history')
        .select('user_id, restaurant_id, swiped_at')
        .eq('user_id', userId)
        .order('swiped_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) =>
            SwipeHistoryModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Clears the user's swipe history so all restaurants become
  /// recommendable again (e.g. "Reset" button on the BlindBox screen).
  Future<void> clearSwipeHistory(String userId) async {
    await SupabaseService.client
        .from('swipe_history')
        .delete()
        .eq('user_id', userId);
  }

  // ---------------------------------------------------------------------------
  // 3. Save Restaurant to Collection
  // ---------------------------------------------------------------------------

  /// Saves a restaurant to the user's default RESTAURANT collection.
  ///
  /// If no default restaurant collection exists, one is created automatically.
  /// Silently skips if the restaurant is already saved (catches duplicate key).
  Future<void> saveRestaurantToCollection({
    required String userId,
    required String restaurantId,
  }) async {
    final collectionId = await _getOrCreateDefaultRestaurantCollection(userId);

    try {
      await SupabaseService.client.from('collections_item').insert({
        'collection_Id': collectionId,
        'restaurant_id': restaurantId,
      });
    } catch (e) {
      final msg = e.toString();
      // Silently ignore if already saved
      if (msg.contains('23505') || msg.contains('duplicate key')) return;
      rethrow;
    }
  }

  /// Checks whether a restaurant is already saved in any of the user's
  /// restaurant collections.
  Future<bool> isRestaurantSaved({
    required String userId,
    required String restaurantId,
  }) async {
    // Get user's restaurant collection IDs
    final collections = await SupabaseService.client
        .from('collections')
        .select('collection_Id')
        .eq('user_Id', userId)
        .eq('collection_type', 'RESTAURANT');

    final collectionIds = (collections as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['collection_Id']?.toString())
        .whereType<String>()
        .toList();

    if (collectionIds.isEmpty) return false;

    final item = await SupabaseService.client
        .from('collections_item')
        .select('item_Id')
        .inFilter('collection_Id', collectionIds)
        .eq('restaurant_id', restaurantId)
        .maybeSingle();

    return item != null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the user's default restaurant collection ID,
  /// creating one if it doesn't exist yet.
  Future<String> _getOrCreateDefaultRestaurantCollection(
      String userId) async {
    // Try to find existing default
    final existing = await SupabaseService.client
        .from('collections')
        .select('collection_Id')
        .eq('user_Id', userId)
        .eq('collection_type', 'RESTAURANT')
        .eq('is_default', true)
        .maybeSingle();

    if (existing != null) {
      return existing['collection_Id'] as String;
    }

    // Create one
    final response = await SupabaseService.client
        .from('collections')
        .insert({
          'user_Id': userId,
          'name': 'Saved Restaurants',
          'collection_type': 'RESTAURANT',
          'is_default': true,
          'is_public': false,
        })
        .select('collection_Id')
        .single();

    return response['collection_Id'] as String;
  }
}
