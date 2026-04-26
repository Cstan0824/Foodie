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

  try {
    const userId = '00000000-0000-0000-0000-000000000001';
    
    // Check what is ACTUALLY in the Likes table for this user
    print('Fetching raw Likes table entries for user...');
    final rawLikes = await supabase.from('Likes').select('*').eq('user_Id', userId);
    print('Raw Likes: $rawLikes');
    
    // Fetch parent posts
    print('Fetching Posts corresponding to those liked IDs...');
    final postIds = (rawLikes as List).map((l) => l['post_Id']).toList();
    if (postIds.isNotEmpty) {
      final posts = await supabase.from('Post').select('post_Id, title').inFilter('post_Id', postIds);
      print('Actual Posts liked by user: $posts');
    }
  } catch (e) {
    print(e.toString());
  }
  exit(0);
}
