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
  final Profile? owner;
  final List<String> latestItemImages; // New field for card preview

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
    this.latestItemImages = const [],
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

    // Handle latest item images (will be populated by repository join)
    final List<String> images = [];
    final items = json['collections_item'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        String? url;
        if (json['collection_type'] == 'POST') {
          final post = item['Post'] as Map<String, dynamic>?;
          if (post != null) {
            final postImages = post['Post_Image'] as List<dynamic>?;
            if (postImages != null && postImages.isNotEmpty) {
              url = postImages[0]['image_url'] as String?;
            }
          }
        } else {
          final rest = item['Restaurant'] as Map<String, dynamic>?;
          if (rest != null) {
            final restImages = rest['Restaurant_Image'] as List<dynamic>?;
            if (restImages != null && restImages.isNotEmpty) {
              String? coverUrl;
              for (final img in restImages) {
                if (img['isCover'] == true) {
                  coverUrl = img['image_url'] as String?;
                  break;
                }
              }
              url = coverUrl ?? restImages[0]['image_url'] as String?;
            }
          }
        }
        if (url != null && url.isNotEmpty) images.add(url);
      }
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
      latestItemImages: images,
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
