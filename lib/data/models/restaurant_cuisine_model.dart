class RestaurantCuisineModel {
  final String restaurantId;
  final String cuisineId;

  const RestaurantCuisineModel({
    required this.restaurantId,
    required this.cuisineId,
  });

  factory RestaurantCuisineModel.fromJson(Map<String, dynamic> json) {
    return RestaurantCuisineModel(
      restaurantId: json['RestaurantId'] as String,
      cuisineId: json['CuisineId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'RestaurantId': restaurantId,
      'CuisineId': cuisineId,
    };
  }
}
