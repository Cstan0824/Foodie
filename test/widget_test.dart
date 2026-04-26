// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taste_spot/main.dart';
import 'package:taste_spot/features/auth/screens/login_screen.dart';

void main() {
  setUpAll(() async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase with dummy values for testing
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'testKey',
    );
  });

  testWidgets('Login screen renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FoodiApp());

    // Verify that the LoginScreen is rendered
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
