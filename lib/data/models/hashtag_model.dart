class HashtagModel {
  final String id;
  final String name;

  const HashtagModel({
    required this.id,
    required this.name,
  });

  factory HashtagModel.fromJson(Map<String, dynamic> json) {
    return HashtagModel(
      id: json['hashtag_id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hashtag_id': id,
      'name': name,
    };
  }
}
