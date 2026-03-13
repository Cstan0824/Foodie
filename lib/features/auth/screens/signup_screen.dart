import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
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

  void _signup() {
    if (!_agreeToTerms) {
      _showTermsAlert();
      return;
    }
    // TODO: Implement actual Supabase signup
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _showTermsAlert() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Terms & Privacy'),
        content: const Text(
            'Please read and agree to our Terms of Service & Privacy Policy to create an account.'),
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                onTap: _signup,
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
                          const TextSpan(text: 'By signing up, you agree to our '),
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
        placeholderStyle: const TextStyle(fontSize: 15, color: AppColors.textLight),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Icon(icon, color: AppColors.textLight, size: 20),
        ),
        decoration: null, // Clear internal decoration
      ),
    );
  }
}

