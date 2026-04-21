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
      detectedAt: json['detectedAt'] != null 
          ? DateTime.tryParse(json['detectedAt'] as String) 
          : null,
      mainCuisineId: json['main_cuisine_id'] as String?,
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
    };
  }
}
