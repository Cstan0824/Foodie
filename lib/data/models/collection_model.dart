import 'profile_model.dart';

class Collection {
  final String collectionId;
  final String userId;
  final String name;
  final String? description;
  final String collectionType;
  final bool isPublic;
  final bool isDefault;
  final DateTime createdAt;
  final Profile? owner; // Added owner info for shared collections

  Collection({
    required this.collectionId,
    required this.userId,
    required this.name,
    this.description,
    this.collectionType = 'POST',
    required this.isPublic,
    this.isDefault = false,
    required this.createdAt,
    this.owner,
  });

  bool get isCloneable => isPublic; // For now, if it's public, it's cloneable

  factory Collection.fromJson(Map<String, dynamic> json) {
    final collectionId =
        (json['collection_Id'] ?? json['collection_id']) as String;
    final userId = (json['user_Id'] ?? json['user_id']) as String;
    final createdAtRaw = (json['created_At'] ?? json['created_at']) as String;

    // Handle nested owner info if present (e.g. from User join)
    Profile? owner;
    if (json['User'] != null) {
      owner = Profile.fromJson(json['User'] as Map<String, dynamic>);
    }

    return Collection(
      collectionId: collectionId,
      userId: userId,
      name: json['name'] as String,
      description: json['description'] as String?,
      collectionType: (json['collection_type'] as String?) ?? 'POST',
      isPublic: json['is_public'] as bool? ?? false,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(createdAtRaw),
      owner: owner,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collection_Id': collectionId,
      'user_Id': userId,
      'name': name,
      if (description != null) 'description': description,
      'collection_type': collectionType,
      'is_public': isPublic,
    };
  }
}
