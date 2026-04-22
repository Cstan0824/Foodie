class Profile {
  final String userId;
  final String name;
  final String? username;
  final String? bio;
  final DateTime createdAt;

  Profile({
    required this.userId,
    required this.name,
    this.username,
    this.bio,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final username = (json['username'] as String?)?.trim();

    return Profile(
      userId: json['user_Id'] as String,
      name: name,
      username: (username != null && username.isNotEmpty)
          ? username
          : name.replaceAll(' ', '').toLowerCase(),
      bio: json['bio'] as String?,
      createdAt: DateTime.parse(json['created_At'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_Id': userId,
      'name': name,
      if (username != null) 'username': username,
      if (bio != null) 'bio': bio,
    };
  }
}
