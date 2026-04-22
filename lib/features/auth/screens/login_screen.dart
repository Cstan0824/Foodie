import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/auth/screens/signup_screen.dart';
import 'package:taste_spot/features/auth/screens/complete_profile_screen.dart';
import 'package:taste_spot/features/auth/screens/forgot_password_screen.dart';
import 'package:taste_spot/features/admin/screens/admin_screen.dart';
import 'package:taste_spot/main.dart'; // To navigate to home for testing

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  late final StreamSubscription<AuthState> _authStateSubscription;

  late final AuthRepository _authRepo = AuthRepository(
    Supabase.instance.client,
  );

  @override
  void initState() {
    super.initState();
    // Listen to authentication state changes (e.g. returning from deep link)
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) async {
          final session = data.session;
          final event = data.event;

          if (session != null &&
              (event == AuthChangeEvent.signedIn ||
                  event == AuthChangeEvent.initialSession)) {
            // Ensure profile exists for OAuth users
            final isNewUser = await _ensureProfileExists(session.user);

            if (!mounted) return;
            if (isNewUser) {
              Navigator.of(context).pushReplacement(
                CupertinoPageRoute(
                  builder: (_) => const CompleteProfileScreen(),
                ),
              );
            } else {
              Navigator.of(context).pushReplacement(
                CupertinoPageRoute(builder: (_) => const MainShell()),
              );
            }
          }
        });
  }

  Future<bool> _ensureProfileExists(User user) async {
    try {
      final response = await Supabase.instance.client
          .from('User')
          .select()
          .eq('user_Id', user.id)
          .maybeSingle();

      if (response == null) {
        // If it's an email user, the AuthRepo might still be creating the profile concurrently,
        // so we wait or simply let AuthRepo handle email profile generation.
        final provider = user.appMetadata['provider'];

        if (provider == 'google' || provider == 'apple') {
          // Create an empty or partial profile for OAuth, user must complete it
          final rawMeta = user.userMetadata;

          final fallbackName =
              (rawMeta?['full_name'] as String?) ??
              (rawMeta?['name'] as String?) ??
              ((user.email != null && user.email!.contains('@'))
                  ? user.email!.split('@').first
                  : 'New Foodie');

          final fallbackUsername = await _buildUniqueUsername(fallbackName);

          await Supabase.instance.client.from('User').insert({
            'user_Id': user.id,
            'name': fallbackName,
            'username': fallbackUsername,
          });
          return true; // Is a new user needing profile completion
        }
      }
      return false; // Existing user or email user (handled by auth repo)
    } catch (e) {
      print('Error ensuring profile exists: $e');
      return false;
    }
  }

  Future<String> _buildUniqueUsername(String seed) async {
    final sanitized = seed.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final base = sanitized.isEmpty ? 'foodie' : sanitized;
    var candidate = base;

    for (var i = 0; i < 20; i++) {
      final available = await _authRepo.isUsernameAvailable(candidate);
      if (available) return candidate;
      candidate = '$base${1000 + Random().nextInt(9000)}';
    }

    return '$base${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  Future<void> _login() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _showErrorAlert('Please enter your email/phone and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepo.signIn(identifier: identifier, password: password);
      // Navigation is now handled automatically by onAuthStateChange listener
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorAlert(e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorAlert('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authRepo.signInWithGoogle();
      // Supabase OAuth handles redirect natively via deep link / browser
    } catch (e) {
      if (!mounted) return;
      _showErrorAlert('An error occurred during Google Login.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);
    try {
      await _authRepo.signInWithApple();
    } catch (e) {
      if (!mounted) return;
      _showErrorAlert('An error occurred during Apple Login.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Login Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.cardBackground,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),

                      // ── App Header / Logo Row ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.flame_fill,
                                color: AppColors.primary,
                                size: 35,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Taste Spot',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your Favorite Flavor',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),

                      // ── Input Fields ──
                      _buildModernTextField(
                        controller: _emailController,
                        placeholder: 'Email or Phone Number',
                        icon: CupertinoIcons.person_fill,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: _passwordController,
                        placeholder: 'Password',
                        icon: CupertinoIcons.lock_fill,
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),

                      // ── Forgot Password ──
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Login Button ──
                      GestureDetector(
                        onTap: _isLoading ? null : _login,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(51),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                  )
                                : const Text(
                                    'Log In',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── Social Login Section ──
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.divider,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Or',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.divider,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialIconButton(
                            child: const Text(
                              'G',
                              style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: _isLoading ? () {} : _loginWithGoogle,
                          ),
                          const SizedBox(width: 24),
                          _buildSocialIconButton(
                            child: const Icon(
                              Icons.apple,
                              color: CupertinoColors.black,
                              size: 28,
                            ),
                            onTap: _isLoading ? () {} : _loginWithApple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      const Spacer(), // Pushes the rest to the bottom
                      const SizedBox(height: 16),

                      // ── Go to Sign up ──
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Sign up',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const SizedBox(height: 24),
                      // ── [TEMP] Admin Entry ── remove when auth module is integrated
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const AdminScreen(),
                            ),
                          );
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F9),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.divider, width: 0.5),
                          ),
                          child: const Center(
                            child: Text(
                              '⚙️  Admin Panel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Helper UI Widgets ──

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        obscureText: obscureText,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        placeholderStyle: const TextStyle(
          fontSize: 15,
          color: AppColors.textLight,
        ),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Icon(icon, color: AppColors.textLight, size: 20),
        ),
        decoration: null, // Clear internal decoration
      ),
    );
  }

  Widget _buildSocialIconButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.textLight.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Center(child: child),
      ),
    );
  }
}
