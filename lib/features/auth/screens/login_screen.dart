import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Colors;
import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/auth/screens/signup_screen.dart';
import 'package:taste_spot/features/auth/screens/complete_profile_screen.dart';
import 'package:taste_spot/features/auth/screens/forgot_password_screen.dart';
import 'package:taste_spot/features/admin/screens/admin_screen.dart';
import 'package:taste_spot/core/services/account_service.dart';
import 'package:taste_spot/main.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  
  bool _isLoading = false;
  late final StreamSubscription<AuthState> _authStateSubscription;

  late final AuthRepository _authRepo = AuthRepository(
    Supabase.instance.client,
  );

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) async {
          final session = data.session;
          final event = data.event;

          if (session != null &&
              (event == AuthChangeEvent.signedIn ||
                  event == AuthChangeEvent.initialSession)) {
            final isNewUser = await _ensureProfileExists(session.user);
            
            // Save account for multi-account support
            final profileResponse = await Supabase.instance.client
                .from('User')
                .select('name, username, role')
                .eq('user_Id', session.user.id)
                .maybeSingle();
            
            String? avatarUrl;
            try {
              final imageResponse = await Supabase.instance.client
                  .from('user_images')
                  .select('image_url')
                  .eq('user_Id', session.user.id)
                  .maybeSingle();
              avatarUrl = imageResponse?['image_url'];
              
              if (avatarUrl == null) {
                // Fallback to UserImage
                final fallback = await Supabase.instance.client
                  .from('UserImage')
                  .select('image_url')
                  .eq('user_Id', session.user.id)
                  .maybeSingle();
                avatarUrl = fallback?['image_url'];
              }
            } catch (_) {}

            final role = profileResponse?['role'] ?? 'user';

            if (profileResponse != null) {
              await AccountService.saveAccount(
                userId: session.user.id,
                name: profileResponse['name'],
                username: profileResponse['username'],
                avatarUrl: avatarUrl,
                role: role,
                sessionJson: jsonEncode(session.toJson()),
              );
            }

            if (!mounted) return;
            if (isNewUser) {
              Navigator.of(context).pushReplacement(
                CupertinoPageRoute(
                  builder: (_) => const CompleteProfileScreen(),
                ),
              );
            } else {
              if (role == 'admin') {
                Navigator.of(context).pushReplacement(
                  CupertinoPageRoute(builder: (_) => AdminScreen()),
                );
              } else {
                Navigator.of(context).pushReplacement(
                  CupertinoPageRoute(builder: (_) => const MainShell()),
                );
              }
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
          final rawMeta = user.userMetadata;

          final fallbackName =
              (rawMeta?['full_name'] as String?) ??
              (rawMeta?['name'] as String?) ??
              ((user.email != null && user.email!.contains('@'))
                  ? user.email!.split('@').first
                  : 'New Foodie');

          final fallbackUsername = await _buildUniqueUsername(fallbackName);

          final avatarUrl =
              (rawMeta?['avatar_url'] as String?) ??
              (rawMeta?['picture'] as String?);

          await Supabase.instance.client.from('User').insert({
            'user_Id': user.id,
            'name': fallbackName,
            'username': fallbackUsername,
            if (avatarUrl != null && avatarUrl.isNotEmpty)
              'avatar_url': avatarUrl,
          });
          return true;
        }
      }
      return false;
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
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: Stack(
        children: [
          // Background soft gradient
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.activeBlue.withAlpha(10),
              ),
            ),
          ),
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 50),

                          // App Branding
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withAlpha(80),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.flame_fill,
                                    color: CupertinoColors.white,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Taste Spot',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Discover your next favorite flavor',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 60),

                          // Input Fields
                          _buildModernTextField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            placeholder: 'Email address',
                            icon: CupertinoIcons.mail_solid,
                          ),
                          const SizedBox(height: 16),
                          _buildModernTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            placeholder: 'Password',
                            icon: CupertinoIcons.lock_fill,
                            obscureText: true,
                          ),
                          
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.of(context).push(
                                CupertinoPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),

                          // Login Button
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _isLoading ? null : _login,
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(27),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withAlpha(60),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          color: CupertinoColors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 40),

                          // Social Login
                          Row(
                            children: [
                              Expanded(child: Container(height: 1, color: AppColors.divider)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Continue with', style: TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              Expanded(child: Container(height: 1, color: AppColors.divider)),
                            ],
                          ),
                          const SizedBox(height: 28),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialButton(
                                icon: Icons.g_mobiledata,
                                color: const Color(0xFF4285F4),
                                size: 40,
                                onTap: _isLoading ? () {} : _loginWithGoogle,
                              ),
                              const SizedBox(width: 24),
                              _buildSocialButton(
                                icon: Icons.apple,
                                color: CupertinoColors.black,
                                size: 28,
                                onTap: _isLoading ? () {} : _loginWithApple,
                              ),
                            ],
                          ),

                          const Spacer(),
                          
                          // Sign up link
                          Center(
                            child: CupertinoButton(
                              onPressed: () => Navigator.of(context).push(
                                CupertinoPageRoute(builder: (_) => const SignupScreen()),
                              ),
                              child: RichText(
                                text: const TextSpan(
                                  text: "Don't have an account? ",
                                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  children: [
                                    TextSpan(
                                      text: 'Sign up',
                                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Admin Entry
                          Center(
                            child: CupertinoButton(
                              onPressed: () => Navigator.of(context).push(
                                CupertinoPageRoute(builder: (_) => AdminScreen()),
                              ),
                              child: Text(
                                'ADMIN ACCESS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textLight.withAlpha(150),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
  }) {
    final bool hasFocus = focusNode.hasFocus;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: hasFocus ? CupertinoColors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: hasFocus ? [
          BoxShadow(color: AppColors.primary.withAlpha(15), blurRadius: 10, offset: const Offset(0, 4)),
        ] : [],
      ),
      child: CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        obscureText: obscureText,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        placeholderStyle: const TextStyle(fontSize: 16, color: AppColors.textLight, fontWeight: FontWeight.w500),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 18.0),
          child: Icon(icon, color: hasFocus ? AppColors.primary : AppColors.textLight, size: 20),
        ),
        decoration: null,
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    double size = 30,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Center(child: Icon(icon, color: color, size: size)),
      ),
    );
  }
}
