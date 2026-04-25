import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await SupabaseService.initialize('dummy', 'dummy');
  // Supabase actually init from env probably? Actually this doesn't run env if it's missing in test.
}
