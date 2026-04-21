import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/gestures.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/auth/screens/signup_screen.dart';
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
  bool _agreeToTerms = false;

  void _login() {
    if (!_agreeToTerms) {
      _showTermsAlert();
      return;
    }
    // TODO: Implement actual login via Supabase
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _showTermsAlert() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Terms & Privacy'),
        content: const Text(
            'Please read and agree to our Terms of Service & Privacy Policy to continue.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.cardBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              // ── App Logo / Icon ──
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.flame_fill,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Welcome Text ──
              const Text(
                'Welcome to Taste Spot',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Discover your next favorite flavor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),

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
                onTap: _login,
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
                  child: const Center(
                    child: Text(
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
                  Expanded(child: Container(height: 1, color: AppColors.divider)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Or continue with',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: AppColors.divider)),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(icon: Icons.apple, onTap: () {}),
                  const SizedBox(width: 24),
                  _buildSocialButton(icon: CupertinoIcons.mail_solid, onTap: () {}),
                ],
              ),
              const SizedBox(height: 50),

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
                          ? const Icon(CupertinoIcons.checkmark_alt,
                              size: 12, color: CupertinoColors.white)
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
                          const TextSpan(text: 'I have read and agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500),
                            recognizer: TapGestureRecognizer()..onTap = () {},
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500),
                            recognizer: TapGestureRecognizer()..onTap = () {},
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

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
        placeholderStyle: const TextStyle(fontSize: 15, color: AppColors.textLight),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Icon(icon, color: AppColors.textLight, size: 20),
        ),
        decoration: null, // Clear internal decoration
      ),
    );
  }

  Widget _buildSocialButton({required IconData icon, required VoidCallback onTap}) {
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
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }
}

