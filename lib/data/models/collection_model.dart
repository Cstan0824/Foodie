class Collection {
  final String collectionId;
  final String userId;
  final String name;
  final String? description;
  final bool isPublic;
  final DateTime createdAt;

  Collection({
    required this.collectionId,
    required this.userId,
    required this.name,
    this.description,
    required this.isPublic,
    required this.createdAt,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      collectionId: json['collection_id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collection_id': collectionId,
      'user_id': userId,
      'name': name,
      if (description != null) 'description': description,
      'is_public': isPublic,
    };
  }
}
