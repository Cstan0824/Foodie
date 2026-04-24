import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Colors;
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math';
import 'package:taste_spot/features/auth/screens/complete_profile_screen.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/auth/screens/verify_otp_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:taste_spot/main.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  Timer? _usernameDebounce;
  bool _isCheckingEmail = false;
  bool? _isEmailTaken;
  Timer? _emailDebounce;
  late final StreamSubscription<AuthState> _authStateSubscription;

  late final AuthRepository _authRepo = AuthRepository(
    Supabase.instance.client,
  );

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(() => setState(() {}));
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
      print('Error ensuring OAuth profile exists: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _usernameDebounce?.cancel();
    _emailDebounce?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
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

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();

    final username = value.trim();
    if (username.isEmpty) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingUsername = true;
        _isUsernameAvailable = null;
      });
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final available = await _authRepo.isUsernameAvailable(username);
        if (!mounted) return;
        if (_usernameController.text.trim() != username) return;
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = available;
        });
      } catch (_) {
        if (!mounted) return;
        if (_usernameController.text.trim() != username) return;
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = null;
        });
      }
    });
  }

  void _onEmailChanged(String value) {
    _emailDebounce?.cancel();

    final email = value.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
          _isEmailTaken = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingEmail = true;
        _isEmailTaken = null;
      });
    }

    _emailDebounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        final taken = await _authRepo.isEmailRegistered(email);
        if (!mounted) return;
        if (_emailController.text.trim() != email) return;
        setState(() {
          _isCheckingEmail = false;
          _isEmailTaken = taken;
        });
      } catch (_) {
        if (!mounted) return;
        if (_emailController.text.trim() != email) return;
        setState(() {
          _isCheckingEmail = false;
          _isEmailTaken = null;
        });
      }
    });
  }

  String _mapUserModuleError(Object error) {
    if (error is PostgrestException) {
      final detailsText = error.details?.toString() ?? '';
      if (error.code == '23505' &&
          (error.message.contains('User_username_key') ||
              detailsText.contains('(username)='))) {
        return 'This username is already taken. Please choose another one.';
      }
      return 'Could not complete profile setup. Please try again.';
    }

    final message = error.toString();
    if (message.contains('USERNAME_TAKEN')) {
      return 'This username is already taken. Please choose another one.';
    }
    if (message.contains('PROFILE_CREATE_FAILED')) {
      return 'Your account was created, but profile setup failed. Please sign in and try again.';
    }

    return 'An unexpected error occurred. Please try again.';
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

    if (_isCheckingUsername) {
      _showAlert(
        'Checking Username',
        'Please wait while we verify your username.',
      );
      return;
    }

    final isAvailable = await _authRepo.isUsernameAvailable(name);
    if (!isAvailable) {
      if (mounted) {
        setState(() => _isUsernameAvailable = false);
      }
      _showAlert(
        'Username Taken',
        'This username is already taken. Please choose another one.',
      );
      return;
    }

    try {
      final emailTaken = await _authRepo.isEmailRegistered(email);
      if (emailTaken) {
        if (mounted) setState(() => _isEmailTaken = true);
        _showAlert(
          'Email Already Registered',
          'This email is already linked to an account. Please log in or use a different email.',
        );
        return;
      }
    } catch (_) {}

    setState(() => _isLoading = true);

    try {
      final response = await _authRepo.signUp(email: email, password: password, name: name);
      final bool disableAuth = dotenv.env['disableAuthForSignUp'] == 'true';

      if (response.session == null && !disableAuth) {
        if (mounted) {
          await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => VerifyOTPScreen(email: email, type: OTPType.signup),
            ),
          );
        }
      } else if (disableAuth) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (_) => const MainShell()),
            (route) => false,
          );
        }
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _showAlert('Signup Failed', _mapUserModuleError(e));
    } on AuthException catch (e) {
      if (!mounted) return;
      _showAlert('Signup Failed', e.message);
    } catch (e) {
      if (!mounted) return;
      _showAlert('Signup Failed', _mapUserModuleError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOtpDialog(String email) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return CupertinoAlertDialog(
            title: const Text('Verify Email'),
            content: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to $email. Please enter it below to verify your account.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: otpController,
                  placeholder: '123456',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    letterSpacing: 8,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () {
                  if (!isVerifying) Navigator.pop(context);
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: isVerifying
                    ? null
                    : () async {
                        final token = otpController.text.trim();
                        if (token.length != 6) return;

                        setStateDialog(() => isVerifying = true);
                        try {
                          await _authRepo.verifySignUpOtp(
                            email: email,
                            token: token,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        } on AuthException catch (e) {
                          setStateDialog(() => isVerifying = false);
                          Navigator.pop(context);
                          _showAlert('Verification Failed', e.message);
                        } catch (e) {
                          setStateDialog(() => isVerifying = false);
                          Navigator.pop(context);
                          _showAlert('Verification Failed', 'An unexpected error occurred. Please try again.');
                        }
                      },
                child: isVerifying
                    ? const CupertinoActivityIndicator()
                    : const Text('Verify'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authRepo.signInWithGoogle();
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
      await _authRepo.signInWithApple();
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
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: null,
        leading: CupertinoNavigationBarBackButton(
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: Stack(
        children: [
          // Background accents
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withAlpha(10)),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  
                  const Text(
                    'Join Taste Spot',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start your flavor journey today.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Input Fields
                  _buildModernTextField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    placeholder: 'Username',
                    icon: CupertinoIcons.person_crop_circle_fill,
                    onChanged: _onUsernameChanged,
                  ),
                  _buildValidationLabel(
                    isChecking: _isCheckingUsername,
                    available: _isUsernameAvailable,
                    takenMsg: 'Username is taken',
                    availMsg: 'Username is available',
                  ),
                  
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    placeholder: 'Email address',
                    icon: CupertinoIcons.mail_solid,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: _onEmailChanged,
                  ),
                  _buildValidationLabel(
                    isChecking: _isCheckingEmail,
                    available: _isEmailTaken == null ? null : !_isEmailTaken!,
                    takenMsg: 'User is not available',
                    availMsg: 'Email is valid',
                  ),

                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    placeholder: 'Password',
                    icon: CupertinoIcons.lock_fill,
                    obscureText: true,
                  ),
                  
                  const SizedBox(height: 32),

                  // Terms row
                  GestureDetector(
                    onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2, right: 12),
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: _agreeToTerms ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _agreeToTerms ? AppColors.primary : AppColors.divider, width: 1.5),
                          ),
                          child: _agreeToTerms
                              ? const Icon(CupertinoIcons.checkmark_alt, size: 14, color: CupertinoColors.white)
                              : null,
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                                  recognizer: TapGestureRecognizer()..onTap = () {},
                                ),
                                const TextSpan(text: ' & '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                                  recognizer: TapGestureRecognizer()..onTap = () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Signup Button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isLoading ? null : _signup,
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
                                'Create Account',
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
                  
                  const SizedBox(height: 48),

                  // Social Login
                  Row(
                    children: [
                      Expanded(child: Container(height: 1, color: AppColors.divider)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Sign up with', style: TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
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
                        onTap: _isLoading ? () {} : _signUpWithGoogle,
                      ),
                      const SizedBox(width: 24),
                      _buildSocialButton(
                        icon: Icons.apple,
                        color: CupertinoColors.black,
                        size: 28,
                        onTap: _isLoading ? () {} : _signUpWithApple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                  
                  Center(
                    child: CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: RichText(
                        text: const TextSpan(
                          text: "Already a member? ",
                          style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(
                              text: 'Sign in',
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
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
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
        keyboardType: keyboardType,
        onChanged: onChanged,
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

  Widget _buildValidationLabel({
    required bool isChecking,
    required bool? available,
    required String takenMsg,
    required String availMsg,
  }) {
    if (isChecking) {
      return const Padding(
        padding: EdgeInsets.only(top: 6, left: 16),
        child: Text('Checking availability...', style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
      );
    }
    if (available == false) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 16),
        child: Text(takenMsg, style: const TextStyle(fontSize: 11, color: CupertinoColors.systemRed, fontWeight: FontWeight.w600)),
      );
    }
    if (available == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 16),
        child: Text(availMsg, style: const TextStyle(fontSize: 11, color: CupertinoColors.activeGreen, fontWeight: FontWeight.w600)),
      );
    }
    return const SizedBox.shrink();
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
