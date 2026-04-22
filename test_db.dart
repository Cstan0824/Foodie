import 'package:flutter/widgets.dart';
import 'package:taste_spot/core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize('dummy', 'dummy'); 
  // Supabase actually init from env probably? Actually this doesn't run env if it's missing in test.
}
