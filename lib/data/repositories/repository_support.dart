import 'package:taste_spot/core/services/supabase_service.dart';

const String publicPostSelect = '''
  post_Id,
  title,
  caption,
  likeCount,
  saveCount,
  created_At,
  User!Post_user_Id_fkey(user_Id, name, UserImage(image_url)),
  Restaurant(
    restaurant_Id,
    restaurant_name,
    main_cuisine_id,
    address,
    latitude,
    longitude
  ),
  Post_Image(image_Id, image_url),
  post_hashtag:post_hashtag!post_hashtag_post_fk(
    hashtag:hashtag!post_hashtag_hashtag_fk(name)
  )
''';

String getPostSelectWithStatus(String? currentUserId) {
  if (currentUserId == null || currentUserId.isEmpty) {
    return publicPostSelect;
  }
  return '''
    $publicPostSelect,
    Likes(user_Id).eq(user_Id, '$currentUserId'),
    collections_item(id).limit(1)
  ''';
}

Future<void> ensurePostAvailable(
  String postId, {
  required String errorMessage,
}) async {
  final response = await SupabaseService.client
      .from('Post')
      .select('post_Id')
      .eq('post_Id', postId)
      .eq('isRemoved', false)
      .eq('isBlocked', false)
      .eq('isPending', false)
      .maybeSingle();

  if (response == null) {
    throw Exception(errorMessage);
  }
}
