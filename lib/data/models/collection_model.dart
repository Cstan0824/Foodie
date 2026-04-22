class Collection {
  final String collectionId;
  final String userId;
  final String name;
  final String? description;
  final bool isPublic;
  final bool isDefault;
  final DateTime createdAt;

  Collection({
    required this.collectionId,
    required this.userId,
    required this.name,
    this.description,
    required this.isPublic,
    this.isDefault = false,
    required this.createdAt,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    final collectionId =
        (json['collection_Id'] ?? json['collection_id']) as String;
    final userId = (json['user_Id'] ?? json['user_id']) as String;
    final createdAtRaw = (json['created_At'] ?? json['created_at']) as String;

    return Collection(
      collectionId: collectionId,
      userId: userId,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(createdAtRaw),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collection_Id': collectionId,
      'user_Id': userId,
      'name': name,
      if (description != null) 'description': description,
      'is_public': isPublic,
    };
  }
}
