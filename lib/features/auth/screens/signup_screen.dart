import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:taste_spot/features/auth/screens/complete_profile_screen.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/main.dart'; // To navigate to home for testing

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreeToTerms = false;
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
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(
                  builder: (_) => const CompleteProfileScreen(),
                ),
                (route) => false,
              );
            } else {
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const MainShell()),
                (route) => false,
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

          await Supabase.instance.client.from('User').insert({
            'user_Id': user.id,
            'name': fallbackName,
            'username': fallbackName,
          });
          return true; // Is a new user needing profile completion
        }
      }
      return false; // Existing user
    } catch (e) {
      print('Error ensuring OAuth profile exists: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_agreeToTerms) {
      _showAlert(
        'Terms & Privacy',
        'Please read and agree to our Terms of Service & Privacy Policy to create an account.',
      );
      return;
    }

    final name = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showAlert('Empty Fields', 'Please fill in all the required fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepo.signUp(email: email, password: password, name: name);
      // Navigation is now handled smoothly by the onAuthStateChange listener
    } on AuthException catch (e) {
      if (!mounted) return;
      _showAlert('Signup Failed', e.message);
    } catch (e) {
      if (!mounted) return;
      _showAlert('Error', 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authRepo
          .signInWithGoogle(); // Sign in handles sign up automatically for OAuth
    } catch (e) {
      if (!mounted) return;
      _showAlert('Error', 'An error occurred during Google Sign Up.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithApple() async {
    setState(() => _isLoading = true);
    try {
      await _authRepo
          .signInWithApple(); // Sign in handles sign up automatically for OAuth
    } catch (e) {
      if (!mounted) return;
      _showAlert('Error', 'An error occurred during Apple Sign Up.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
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
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.cardBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.cardBackground,
        border: null,
        leading: CupertinoNavigationBarBackButton(
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // ── Header ──
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join the community and share your taste!',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),

              // ── Input Fields ──
              _buildModernTextField(
                controller: _usernameController,
                placeholder: 'Username',
                icon: CupertinoIcons.person_crop_circle,
              ),
              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _emailController,
                placeholder: 'Email',
                icon: CupertinoIcons.mail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _passwordController,
                placeholder: 'Password',
                icon: CupertinoIcons.lock,
                obscureText: true,
              ),
              const SizedBox(height: 40),

              // ── Sign Up Button ──
              GestureDetector(
                onTap: _isLoading ? null : _signup,
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
                            'Sign Up',
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

              // ── Terms & Conditions Checkbox ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                    child: Container(
                      margin: const EdgeInsets.only(top: 2, right: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _agreeToTerms ? AppColors.primary : null,
                        border: Border.all(
                          color: _agreeToTerms
                              ? AppColors.primary
                              : AppColors.textLight,
                          width: 1.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: _agreeToTerms
                          ? const Icon(
                              CupertinoIcons.checkmark_alt,
                              size: 12,
                              color: CupertinoColors.white,
                            )
                          : null,
                    ),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text: 'By signing up, you agree to our ',
                          ),
                          TextSpan(
                            text: 'Terms of Service',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = () {},
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = () {},
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // ── Social Login Section ──
              Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: AppColors.divider),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Or sign up with',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(height: 1, color: AppColors.divider),
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
                    onTap: _isLoading ? () {} : _signUpWithGoogle,
                  ),
                  const SizedBox(width: 24),
                  _buildSocialIconButton(
                    child: const Icon(
                      Icons.apple,
                      color: CupertinoColors.black,
                      size: 28,
                    ),
                    onTap: _isLoading ? () {} : _signUpWithApple,
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // ── Have an account? ──
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: RichText(
                    text: const TextSpan(
                      text: "Already have an account? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: 'Log In',
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
              const SizedBox(height: 40),
            ],
          ),
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
    TextInputType? keyboardType,
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
        keyboardType: keyboardType,
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
