import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

Future<void> main() async {
  final lines = File('.env').readAsLinesSync();
  String url = '';
  String key = '';
  for (var line in lines) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1];
    if (line.startsWith('SUPABASE_ANON_KEY=')) key = line.split('=')[1];
  }

  final supabase = SupabaseClient(url, key);
  const userId = '00000000-0000-0000-0000-000000000001';

  try {
    final response = await supabase
        .from('Post')
        .select('''
          post_Id,
          title,
          caption,
          likeCount,
          saveCount,
          created_At,
          User!Post_user_Id_fkey(user_Id, name),
          Restaurant(restaurant_Id, restaurant_name, categoryCuisine),
          Post_Image(image_Id, image_url),
          Likes!inner(user_Id)
        ''')
        .eq('Likes.user_Id', userId)
        .eq('isRemoved', false)
        .order('created_At', ascending: false);

    print(response.first);
  } catch (e) {
    print(e.toString());
  }
  exit(0);
}
