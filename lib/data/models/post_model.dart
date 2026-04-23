class PostModel {
  final String id;
  final String userId;
  final String? restaurantId;
  final String? restaurantApprovalId;
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
  final DateTime? createdAt;
  final List<String> hashtags;

  const PostModel({
    required this.id,
    required this.userId,
    this.restaurantId,
    this.restaurantApprovalId,
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
    this.createdAt,
    this.hashtags = const [],
  });

  PostModel copyWith({
    String? title,
    String? description,
    int? likes,
    int? saveCount,
    List<String>? hashtags,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      restaurantId: restaurantId,
      restaurantApprovalId: restaurantApprovalId,
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
      createdAt: createdAt,
      hashtags: hashtags ?? this.hashtags,
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
    final restaurantId = restaurant?['restaurant_Id'] as String?;

    final createdAtRaw = json['created_At'] as String?;
    final hashtags = <String>[];

    // Get all image URLs from joined Post_Image rows
    final List<String> imageUrls = [];
    final postImages = json['Post_Image'] as List<dynamic>?;
    if (postImages != null) {
      for (final img in postImages) {
        final url = (img as Map<String, dynamic>)['image_url'] as String?;
        if (url != null && url.isNotEmpty) imageUrls.add(url);
      }
    }

    final rawHashtagLinks = json['post_hashtag'] as List<dynamic>?;
    if (rawHashtagLinks != null) {
      for (final entry in rawHashtagLinks) {
        final link = entry as Map<String, dynamic>;
        final hashtag = link['hashtag'] as Map<String, dynamic>?;
        final name = hashtag?['name'] as String?;
        if (name != null && name.isNotEmpty && !hashtags.contains(name)) {
          hashtags.add(name);
        }
      }
      hashtags.sort();
    }

    return PostModel(
      id: json['post_Id'] as String,
      userId: (user?['user_Id'] as String?) ?? '',
      restaurantId: restaurantId,
      restaurantApprovalId: json['restaurant_approval_id'] as String?,
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
      createdAt:
          createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null,
      hashtags: hashtags,
    );
  }
}
