class CollectionItemModel {
  final String itemId;
  final String collectionId;
  final String? restaurantId;
  final String? postId;
  final DateTime savedAt;

  const CollectionItemModel({
    required this.itemId,
    required this.collectionId,
    this.restaurantId,
    this.postId,
    required this.savedAt,
  });

  factory CollectionItemModel.fromJson(Map<String, dynamic> json) {
    return CollectionItemModel(
      itemId: json['item_Id'] as String,
      collectionId: json['collection_Id'] as String,
      restaurantId: json['restaurant_id'] as String?,
      postId: json['post_id'] as String?,
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_Id': itemId,
      'collection_Id': collectionId,
      'restaurant_id': restaurantId,
      'post_id': postId,
      'savedAt': savedAt.toIso8601String(),
    };
  }
}
