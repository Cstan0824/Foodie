class RestaurantModel {
  final String restaurantId;
  final String name;
  final String? mainCuisineId;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? mapsUrl;
  final DateTime? createdAt;
  final String? source;
  final String? infoUrl;
  final bool isDisabled;
  final double? rating;
  /// this is a list of image URLs from the restaurant_image table, not the main restaurant table, so it can be empty
  final List<String> imageUrls;

  const RestaurantModel({
    required this.restaurantId,
    required this.name,
    this.mainCuisineId,
    this.address,
    this.latitude,
    this.longitude,
    this.mapsUrl,
    this.createdAt,
    this.source,
    this.infoUrl,
    this.isDisabled = false,
    this.rating,
    this.imageUrls = const [],
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final mainCuisine =
        json['mainCuisine'] as Map<String, dynamic>? ??
        json['Cuisine'] as Map<String, dynamic>?;

    return RestaurantModel(
      restaurantId: json['restaurant_Id'] as String,
      name: (json['restaurant_name'] as String?) ?? 'Unknown',
      mainCuisineId:
          (mainCuisine?['description'] as String?) ??
          (mainCuisine?['desc'] as String?) ??
          json['main_cuisine_id']?.toString() ??
          json['categoryCuisine'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      mapsUrl: json['maps_url'] as String?,
      createdAt: json['created_At'] != null
          ? DateTime.tryParse(json['created_At'] as String)
          : null,
      source: json['source'] as String?,
      infoUrl: json['info_url'] as String?,
      isDisabled: json['isDisabled'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble(),
      imageUrls: () {
        final images = List<Map<String, dynamic>>.from(
          (json['Restaurant_Image'] as List<dynamic>?) ?? [],
        );
        // Sort so cover image (isCover == true) is always first.
        images.sort((a, b) {
          final aCover = a['isCover'] == true ? 0 : 1;
          final bCover = b['isCover'] == true ? 0 : 1;
          return aCover.compareTo(bCover);
        });
        return images
            .map((img) => img['image_url'] as String)
            .toList();
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurant_Id': restaurantId,
      'restaurant_name': name,
      'main_cuisine_id': mainCuisineId,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'maps_url': mapsUrl,
      'created_At': createdAt?.toIso8601String(),
      'source': source,
      'info_url': infoUrl,
      'isDisabled': isDisabled,
      'rating': rating,
      'image_urls': imageUrls,
    };
  }
}
