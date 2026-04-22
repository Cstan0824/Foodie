class RestaurantModel {
  final String restaurantId;
  final String name;
  final String? cuisine;
  final String? address;
  final String? mapsUrl;

  const RestaurantModel({
    required this.restaurantId,
    required this.name,
    this.cuisine,
    this.address,
    this.mapsUrl,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final mainCuisine =
        json['mainCuisine'] as Map<String, dynamic>? ?? json['Cuisine'] as Map<String, dynamic>?;

    return RestaurantModel(
      restaurantId: json['restaurant_Id'] as String,
      name: (json['restaurant_name'] as String?) ?? 'Unknown',
      cuisine:
          (mainCuisine?['desc'] as String?) ?? json['categoryCuisine'] as String?,
      address: json['address'] as String?,
      mapsUrl: json['maps_url'] as String?,
    );
  }
}
