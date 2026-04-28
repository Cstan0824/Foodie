import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Colors;
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/auth/screens/signup_screen.dart';
import 'package:taste_spot/features/auth/screens/complete_profile_screen.dart';
import 'package:taste_spot/features/auth/screens/forgot_password_screen.dart';
import 'package:taste_spot/features/auth/screens/verify_otp_screen.dart';
import 'package:taste_spot/features/admin/screens/admin_screen.dart';
import 'package:taste_spot/core/services/account_service.dart';
import 'package:taste_spot/main.dart';
import 'dart:convert';
import 'package:taste_spot/core/widgets/feedback_dialog.dart';

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
  bool _emailError = false;
  bool _passwordError = false;
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
          try {
            final session = data.session;
            final event = data.event;

            if (session != null &&
                (event == AuthChangeEvent.signedIn ||
                    event == AuthChangeEvent.initialSession)) {
              
              if (mounted) setState(() => _isLoading = true);

              final isNewUser = await _ensureProfileExists(session.user);
              
              final profileResponse = await Supabase.instance.client
                  .from('User')
                  .select('name, username, role')
                  .eq('user_Id', session.user.id)
                  .maybeSingle();
              
              String? avatarUrl;
              try {
                final imageResponse = await Supabase.instance.client
                    .from('UserImage')
                    .select('image_url')
                    .eq('user_Id', session.user.id)
                    .maybeSingle();
                avatarUrl = imageResponse?['image_url'];
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
                  CupertinoPageRoute(builder: (_) => const CompleteProfileScreen()),
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
          } catch (e) {
            debugPrint('Login Auth Listener Error: $e');
            if (mounted) setState(() => _isLoading = false);
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
      return response == null;
    } catch (e) {
      return false;
    }
  }

  String _mapAuthError(Object error) {
    final message = error.toString();
    if (message.contains('Invalid login credentials')) {
      return 'Incorrect email or password. Please check your details and try again.';
    }
    if (message.contains('over_email_send_rate_limit')) {
      return 'Too many attempts. Please wait a few minutes before trying again.';
    }
    if (message.contains('network_error')) {
      return 'Connection problem. Please check your internet and try again.';
    }
    return 'Something went wrong when trying to sign in. Please try again later.';
  }

  Future<void> _login() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = identifier.isEmpty;
      _passwordError = password.isEmpty;
    });

    if (_emailError || _passwordError) {
      FeedbackDialog.show(
        context: context,
        title: 'Sign In',
        message: 'Please enter both your email and password.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepo.signIn(identifier: identifier, password: password);
    } on AuthException catch (e) {
      if (mounted) {
        FeedbackDialog.show(context: context, title: 'Sign In Failed', message: _mapAuthError(e));
      }
    } catch (e) {
      if (mounted) {
        FeedbackDialog.show(context: context, title: 'Sign In Problem', message: _mapAuthError(e));
      }
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
      FeedbackDialog.show(context: context, title: 'Google Sign In', message: _mapAuthError(e));
    } finally {
      // Note: We don't set _isLoading = false here if it's successful 
      // because the onAuthStateChange listener will handle the transition.
      // But in case of error, we must reset it.
      if (mounted) {
        // We only reset if there was an error that didn't lead to a sign-in event
        // Actually, the SDK might take time to return from signInWithOAuth.
      }
    }
  }

  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);
    try {
      await _authRepo.signInWithApple();
    } catch (e) {
      if (!mounted) return;
      FeedbackDialog.show(context: context, title: 'Apple Sign In', message: _mapAuthError(e));
    } finally {
      // Same logic as Google login
    }
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
    return Stack(
      children: [
        CupertinoPageScaffold(
          backgroundColor: CupertinoColors.white,
          child: Stack(
            children: [
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withAlpha(15)),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: CupertinoColors.activeBlue.withAlpha(10)),
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

                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 20, offset: const Offset(0, 8)),
                                        ],
                                      ),
                                      child: const Icon(CupertinoIcons.flame_fill, color: CupertinoColors.white, size: 40),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Foodie',
                                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1.2),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Discover your next favorite flavor',
                                      style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 60),

                              _buildModernTextField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                placeholder: 'Email address',
                                icon: CupertinoIcons.mail_solid,
                                isError: _emailError,
                                onChanged: (_) {
                                  if (_emailError) setState(() => _emailError = false);
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildModernTextField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                placeholder: 'Password',
                                icon: CupertinoIcons.lock_fill,
                                obscureText: true,
                                isError: _passwordError,
                                onChanged: (_) {
                                  if (_passwordError) setState(() => _passwordError = false);
                                },
                              ),
                              
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => Navigator.of(context).push(
                                    CupertinoPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                  ),
                                  child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              
                              const SizedBox(height: 24),

                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _isLoading ? null : _login,
                                child: Container(
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(27),
                                    boxShadow: [
                                      BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 15, offset: const Offset(0, 6)),
                                    ],
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                                        : const Text(
                                            'Sign In',
                                            style: TextStyle(color: CupertinoColors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                                          ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 40),

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
                              const SizedBox(height: 24),
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
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withAlpha(100),
            child: const Center(
              child: CupertinoActivityIndicator(radius: 15, color: CupertinoColors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    bool isError = false,
    ValueChanged<String>? onChanged,
  }) {
    final bool hasFocus = focusNode.hasFocus;
    final Color borderColor = isError 
        ? CupertinoColors.systemRed 
        : (hasFocus ? AppColors.primary : Colors.transparent);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: hasFocus ? CupertinoColors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: hasFocus || isError ? [
          BoxShadow(
            color: (isError ? CupertinoColors.systemRed : AppColors.primary).withAlpha(15), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          ),
        ] : [],
      ),
      child: CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        obscureText: obscureText,
        onChanged: onChanged,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        placeholderStyle: const TextStyle(fontSize: 16, color: AppColors.textLight, fontWeight: FontWeight.w500),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 18.0),
          child: Icon(icon, color: isError ? CupertinoColors.systemRed : (hasFocus ? AppColors.primary : AppColors.textLight), size: 20),
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
            BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 15, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Center(child: Icon(icon, color: color, size: size)),
      ),
    );
  }
}
