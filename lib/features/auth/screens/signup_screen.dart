import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math';
import 'package:taste_spot/features/auth/screens/complete_profile_screen.dart';
import 'package:taste_spot/features/auth/screens/verify_otp_screen.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/main.dart';
import 'package:taste_spot/core/widgets/feedback_dialog.dart';

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
  bool? _isPasswordValid;
  Timer? _usernameDebounce;
  bool _isCheckingEmail = false;
  bool? _isEmailTaken;
  bool _signupAttempted = false;
  bool _isHandlingOtp = false;
  Timer? _emailDebounce;
  late final StreamSubscription<AuthState> _authStateSubscription;

  late final AuthRepository _authRepo = AuthRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (_isHandlingOtp) return;
      try {
        final session = data.session;
        if (session != null && (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.initialSession)) {
          final isNewUser = await _ensureProfileExists(session.user);
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (_) => isNewUser ? const CompleteProfileScreen() : const MainShell()),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint('Signup Auth Listener Error: $e');
      }
    });
  }

  Future<bool> _ensureProfileExists(User user) async {
    try {
      final response = await Supabase.instance.client.from('User').select().eq('user_Id', user.id).maybeSingle();
      if (response == null) {
        final provider = user.appMetadata['provider'];
        if (provider == 'google' || provider == 'apple') {
          final rawMeta = user.userMetadata;
          final fallbackName = (rawMeta?['full_name'] as String?) ?? 'New Foodie';
          final fallbackUsername = await _buildUniqueUsername(fallbackName);
          await Supabase.instance.client.from('User').insert({
            'user_Id': user.id,
            'name': fallbackName,
            'username': fallbackUsername,
            'password': 'SOCIAL_LOGIN',
          });
          return true;
        }
      }
      return false;
    } catch (_) { return false; }
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
    for (var i = 0; i < 10; i++) {
      final available = await _authRepo.isUsernameAvailable(candidate);
      if (available) return candidate;
      candidate = '$base${100 + Random().nextInt(900)}';
    }
    return '$base${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final username = value.trim();
    if (username.isEmpty) {
      if (mounted) setState(() { _isCheckingUsername = false; _isUsernameAvailable = null; });
      return;
    }
    if (mounted) setState(() { _isCheckingUsername = true; _isUsernameAvailable = null; });
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final available = await _authRepo.isUsernameAvailable(username);
        if (!mounted || _usernameController.text.trim() != username) return;
        setState(() {
          _isUsernameAvailable = available;
        });
      } catch (_) {
      } finally {
        if (mounted && _usernameController.text.trim() == username) {
          setState(() { _isCheckingUsername = false; });
        }
      }
    });
  }

  void _onEmailChanged(String value) {
    _emailDebounce?.cancel();
    final email = value.trim();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      if (mounted) setState(() { _isCheckingEmail = false; _isEmailTaken = null; });
      return;
    }
    if (mounted) setState(() { _isCheckingEmail = true; _isEmailTaken = null; });
    _emailDebounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        final taken = await _authRepo.isEmailRegistered(email);
        if (!mounted || _emailController.text.trim() != email) return;
        setState(() {
          _isEmailTaken = taken;
        });
      } catch (_) {
      } finally {
        if (mounted && _emailController.text.trim() == email) {
          setState(() { _isCheckingEmail = false; });
        }
      }
    });
  }

  Future<void> _signup() async {
    setState(() => _signupAttempted = true);

    if (!_agreeToTerms) {
      FeedbackDialog.show(context: context, title: 'Terms of Service', message: 'Please agree to our terms to continue.', icon: CupertinoIcons.doc_text_fill);
      return;
    }

    final name = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isPasswordValid = password.isNotEmpty && password.length >= 8;
    });

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      FeedbackDialog.show(context: context, title: 'Incomplete', message: 'Please fill in all fields.');
      return;
    }

    if (password.length < 8) {
      FeedbackDialog.show(context: context, title: 'Password Too Short', message: 'For your security, please use at least 8 characters for your password.', icon: CupertinoIcons.lock_shield_fill);
      return;
    }

    if (_isUsernameAvailable == false) return;
    if (_isEmailTaken == true) return;

    setState(() => _isLoading = true);

    try {
      final response = await _authRepo.signUp(email: email, password: password, name: name);
      if (!mounted) return;
      
      // If session is null but user is not null, it means verification is required (OTP)
      if (response.session == null && response.user != null) {
        setState(() => _isHandlingOtp = true);
        
        final verified = await Navigator.of(context).push<bool>(
          CupertinoPageRoute(
            builder: (_) => VerifyOTPScreen(email: email, type: OTPType.signup),
          ),
        );

        if (verified == true && mounted) {
          // After OTP success, the profile is already created in verifySignUpOtp
          // We can now safely navigate
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            final isNewUser = await _ensureProfileExists(user);
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(builder: (_) => isNewUser ? const CompleteProfileScreen() : const MainShell()),
              (route) => false,
            );
          }
        } else {
          if (mounted) setState(() => _isHandlingOtp = false);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        FeedbackDialog.show(context: context, title: 'Sign Up Failed', message: e.message);
      }
    } catch (e) {
      if (mounted) {
        FeedbackDialog.show(context: context, title: 'Sign Up Problem', message: 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: const CupertinoNavigationBar(backgroundColor: CupertinoColors.white, border: null),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text('Join Taste Spot', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1.2)),
              const SizedBox(height: 8),
              const Text('Start your flavor journey today.', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: 48),

              _buildModernTextField(
                controller: _usernameController,
                focusNode: _usernameFocus,
                placeholder: 'Username',
                icon: CupertinoIcons.person_crop_circle_fill,
                onChanged: (v) {
                  _onUsernameChanged(v);
                  if (_signupAttempted) setState(() {});
                },
                status: _isUsernameAvailable,
                isChecking: _isCheckingUsername,
                isError: _signupAttempted && _usernameController.text.trim().isEmpty,
              ),
              _buildErrorLabel(_isUsernameAvailable == false, 'Username is not available'),
              
              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _emailController,
                focusNode: _emailFocus,
                placeholder: 'Email address',
                icon: CupertinoIcons.mail_solid,
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) {
                  _onEmailChanged(v);
                  if (_signupAttempted) setState(() {});
                },
                status: _isEmailTaken == null ? null : !_isEmailTaken!,
                isChecking: _isCheckingEmail,
                isError: _signupAttempted && (_emailController.text.trim().isEmpty || !(_isEmailTaken == null ? true : !_isEmailTaken!)),
              ),
              _buildErrorLabel(_isEmailTaken == true, 'Email is already registered'),

              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                placeholder: 'Password',
                icon: CupertinoIcons.lock_fill,
                obscureText: true,
                onChanged: (_) {
                  if (_signupAttempted) setState(() {});
                },
                isError: _signupAttempted && (_passwordController.text.isEmpty || _passwordController.text.length < 8),
              ),
              
              const SizedBox(height: 32),

              GestureDetector(
                onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(color: _agreeToTerms ? AppColors.primary : AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: _agreeToTerms ? AppColors.primary : AppColors.divider)),
                      child: _agreeToTerms ? const Icon(CupertinoIcons.checkmark_alt, size: 14, color: CupertinoColors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('I agree to the Terms & Privacy Policy', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _signup,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(27), boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 15, offset: const Offset(0, 6))]),
                  alignment: Alignment.center,
                  child: _isLoading ? const CupertinoActivityIndicator(color: CupertinoColors.white) : const Text('Create Account', style: TextStyle(color: CupertinoColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
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
    bool? status,
    bool isChecking = false,
    bool isError = false,
  }) {
    final bool hasFocus = focusNode.hasFocus;
    Color borderColor = Colors.transparent;
    
    if (isError || status == false) {
      borderColor = CupertinoColors.systemRed;
    } else if (hasFocus) {
      if (status == true) {
        borderColor = CupertinoColors.activeGreen;
      } else {
        // Default focus color is Green as requested
        borderColor = CupertinoColors.activeGreen;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: hasFocus ? CupertinoColors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: hasFocus || isError || status == false ? [
          BoxShadow(
            color: (borderColor == Colors.transparent ? AppColors.primary : borderColor).withAlpha(20), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ] : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(icon, color: borderColor != Colors.transparent ? borderColor : AppColors.textLight, size: 20),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              focusNode: focusNode,
              placeholder: placeholder,
              obscureText: obscureText,
              keyboardType: keyboardType,
              onChanged: onChanged,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              placeholderStyle: const TextStyle(fontSize: 16, color: AppColors.textLight),
              decoration: null,
            ),
          ),
          if (isChecking) const Padding(padding: EdgeInsets.only(right: 16), child: CupertinoActivityIndicator(radius: 8)),
          if (!isChecking && status == true) const Padding(padding: EdgeInsets.only(right: 16), child: Icon(CupertinoIcons.checkmark_alt_circle_fill, color: CupertinoColors.activeGreen, size: 20)),
          if (!isChecking && (status == false || isError)) const Padding(padding: EdgeInsets.only(right: 16), child: Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemRed, size: 20)),
        ],
      ),
    );
  }

  Widget _buildErrorLabel(bool show, String message) {
    if (!show) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 6, left: 16), child: Text(message, style: const TextStyle(fontSize: 11, color: CupertinoColors.systemRed, fontWeight: FontWeight.w600)));
  }
}
