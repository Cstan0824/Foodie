import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';

class RestaurantRepository {
  RestaurantRepository._();
  static final RestaurantRepository instance = RestaurantRepository._();

  /// Searches restaurants by name (case-insensitive prefix match).
  Future<List<RestaurantModel>> searchRestaurants(String query,
      {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final response = await SupabaseService.client
        .from('Restaurant')
        .select('restaurant_Id, restaurant_name, main_cuisine_id, address, maps_url, created_At, latitude, longitude, source, info_url, isDisabled')
        .ilike('restaurant_name', '%$query%')
        .order('restaurant_name')
        .limit(limit);

    return (response as List<dynamic>)
        .map((row) => RestaurantModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches all restaurants (for showing a default list before search).
  Future<List<RestaurantModel>> fetchRecent({int limit = 10}) async {
    final response = await SupabaseService.client
        .from('Restaurant')
        .select('restaurant_Id, restaurant_name, main_cuisine_id, address, maps_url, created_At, latitude, longitude, source, info_url, isDisabled')
        .order('created_At', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((row) => RestaurantModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
