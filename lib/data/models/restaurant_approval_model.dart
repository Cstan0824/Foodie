import 'package:taste_spot/core/utils/app_time.dart';

class RestaurantApprovalModel {
  final String approvalId;
  final String? currRestaurantId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? mapsUrl;
  final String? source;
  final int status; // 0 = not reviewed, 1 = accepted, 2 = rejected
  final DateTime? detectedAt;
  final String? mainCuisineId;
  final double? rating;
  final String? description;
  final String? priceRange;

  /// this is in the restaurant approval table, not the main restaurant table, so it can be null
  final String? imageUrl;

  const RestaurantApprovalModel({
    required this.approvalId,
    this.currRestaurantId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.mapsUrl,
    this.source,
    required this.status,
    this.detectedAt,
    this.mainCuisineId,
    this.rating,
    this.description,
    this.priceRange,
    this.imageUrl,
  });

  factory RestaurantApprovalModel.fromJson(Map<String, dynamic> json) {
    return RestaurantApprovalModel(
      approvalId: json['approval_Id'] as String,
      currRestaurantId: json['curr_restaurant_id'] as String?,
      name: (json['restaurant_name'] as String?) ?? 'Unknown',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      mapsUrl: json['maps_url'] as String?,
      source: json['source'] as String?,
      status: json['status'] as int? ?? 0,
      detectedAt: AppTime.parseUtc(json['detectedAt']),
      mainCuisineId: json['main_cuisine_id'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      description: json['description'] as String?,
      priceRange: json['price_range'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'approval_Id': approvalId,
      'curr_restaurant_id': currRestaurantId,
      'restaurant_name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'maps_url': mapsUrl,
      'source': source,
      'status': status,
      'detectedAt': detectedAt?.toIso8601String(),
      'main_cuisine_id': mainCuisineId,
      'rating': rating,
      'image_url': imageUrl,
    };
  }
}
