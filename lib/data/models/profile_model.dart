class Profile {
  final String userId;
  final String name;
  final String? username;
  final String? bio;
  final String role; // 'user' or 'admin'
  final DateTime createdAt;
  final String? imageUrl;

  Profile({
    required this.userId,
    required this.name,
    this.username,
    this.bio,
    this.role = 'user',
    required this.createdAt,
    this.imageUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final username = (json['username'] as String?)?.trim();

    // Handle nested image_url from UserImage or user_images join
    String? imageUrl = json['image_url'] as String?;
    if (imageUrl == null) {
      final userImages = json['UserImage'] ?? json['user_images'];
      if (userImages != null) {
        if (userImages is List && userImages.isNotEmpty) {
          imageUrl = userImages[0]['image_url'] as String?;
        } else if (userImages is Map) {
          imageUrl = userImages['image_url'] as String?;
        }
      }
    }
    
    // Fallback to avatar_url if still null
    imageUrl ??= json['avatar_url'] as String?;

    return Profile(
      userId: json['user_Id'] as String,
      name: name,
      username: (username != null && username.isNotEmpty)
          ? username
          : name.replaceAll(' ', '').toLowerCase(),
      bio: json['bio'] as String?,
      role: json['role'] as String? ?? 'user',
      createdAt: DateTime.parse(json['created_At'] as String),
      imageUrl: imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_Id': userId,
      'name': name,
      if (username != null) 'username': username,
      if (bio != null) 'bio': bio,
      'role': role,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}
