class PostHashtagModel {
  final String postId;
  final String hashtagId;

  const PostHashtagModel({
    required this.postId,
    required this.hashtagId,
  });

  factory PostHashtagModel.fromJson(Map<String, dynamic> json) {
    return PostHashtagModel(
      postId: json['post_Id'] as String,
      hashtagId: json['hashtag_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_Id': postId,
      'hashtag_id': hashtagId,
    };
  }
}
