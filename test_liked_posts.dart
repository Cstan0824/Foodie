import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  // Read .env manually
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
    print('Testing query...');
    final response = await supabase
        .from('Post')
        .select('''
          post_Id,
          title,
          Likes!inner(user_Id)
        ''')
        .eq('Likes.user_Id', userId)
        .eq('isRemoved', false);

    print('SUCCESS:');
    print(response);
  } catch (e) {
    print('ERROR:');
    print(e.toString());
  }
  exit(0);
}
