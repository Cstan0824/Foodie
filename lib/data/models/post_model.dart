class PostModel {
  final String id;
  final String userId;
  final String? restaurantId;
  final String imageUrl;
  final List<String> imageUrls;
  final double aspectRatio;
  final String title;
  final String description;
  final String authorName;
  final String authorAvatar;
  final int likes;
  final int saveCount;
  final String? location;
  final String restaurantName;
  final String restaurantCuisine;
  final DateTime? createdAt;

  const PostModel({
    required this.id,
    required this.userId,
    this.restaurantId,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.aspectRatio,
    required this.title,
    this.description = '',
    required this.authorName,
    required this.authorAvatar,
    required this.likes,
    this.saveCount = 0,
    this.location,
    this.restaurantName = '',
    this.restaurantCuisine = '',
    this.createdAt,
  });

  PostModel copyWith({
    String? title,
    String? description,
    int? likes,
    int? saveCount,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      restaurantId: restaurantId,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      aspectRatio: aspectRatio,
      title: title ?? this.title,
      description: description ?? this.description,
      authorName: authorName,
      authorAvatar: authorAvatar,
      likes: likes ?? this.likes,
      saveCount: saveCount ?? this.saveCount,
      location: location,
      restaurantName: restaurantName,
      restaurantCuisine: restaurantCuisine,
      createdAt: createdAt,
    );
  }

  /// Maps a Supabase `Post` row with joined `User` + `Restaurant`.
  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Supabase returns the joined User under the FK name when disambiguated
    final user =
        (json['User!Post_user_Id_fkey'] ?? json['User'])
            as Map<String, dynamic>?;
    final authorName = (user?['name'] as String?) ?? 'Unknown';

    final restaurant = json['Restaurant'] as Map<String, dynamic>?;
    final restaurantName = (restaurant?['restaurant_name'] as String?) ?? '';
    final mainCuisine = restaurant?['mainCuisine'];
    final restaurantCuisine = switch (mainCuisine) {
      final Map<String, dynamic> cuisine =>
        (cuisine['description'] as String?) ?? '',
      final List<dynamic> cuisines when cuisines.isNotEmpty =>
        ((cuisines.first as Map<String, dynamic>)['description'] as String?) ??
            '',
      _ => '',
    };
    final restaurantId = restaurant?['restaurant_Id'] as String?;

    final createdAtRaw = json['created_At'] as String?;

    // Get all image URLs from joined Post_Image rows
    final List<String> imageUrls = [];
    final postImages = json['Post_Image'] as List<dynamic>?;
    if (postImages != null) {
      for (final img in postImages) {
        final url = (img as Map<String, dynamic>)['image_url'] as String?;
        if (url != null && url.isNotEmpty) imageUrls.add(url);
      }
    }

    return PostModel(
      id: json['post_Id'] as String,
      userId: (user?['user_Id'] as String?) ?? '',
      restaurantId: restaurantId,
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
      imageUrls: imageUrls,
      aspectRatio: 1.3,
      title: (json['title'] as String?) ?? '',
      description: (json['caption'] as String?) ?? '',
      authorName: authorName,
      authorAvatar: '',
      likes: (json['likeCount'] as num?)?.toInt() ?? 0,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      restaurantName: restaurantName,
      restaurantCuisine: restaurantCuisine,
      createdAt: createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null,
    );
  }
}
