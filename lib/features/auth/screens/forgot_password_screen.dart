import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/features/auth/screens/verify_otp_screen.dart';
import 'package:taste_spot/features/auth/screens/reset_password_screen.dart';
import 'package:taste_spot/core/widgets/feedback_dialog.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailError = false;

  late final AuthRepository _authRepo = AuthRepository(Supabase.instance.client);

  String _mapResetError(Object error) {
    final message = error.toString();
    if (message.contains('over_email_send_rate_limit')) {
      return 'Too many requests. Please wait a few minutes before trying to send another reset email.';
    }
    if (message.contains('network_error')) {
      return 'Connection problem. Please check your internet and try again.';
    }
    return 'Something went wrong when trying to send reset instructions. Please try again.';
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    
    setState(() {
      _emailError = email.isEmpty;
    });

    if (email.isEmpty) {
      FeedbackDialog.show(context: context, title: 'Reset Password', message: 'Please enter your email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepo.resetPassword(email: email);
      if (!mounted) return;
      
      final verified = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          builder: (_) => VerifyOTPScreen(email: email, type: OTPType.recovery),
        ),
      );

      if (verified == true && mounted) {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      FeedbackDialog.show(context: context, title: 'Reset Failed', message: _mapResetError(e));
    } catch (e) {
      if (!mounted) return;
      FeedbackDialog.show(context: context, title: 'Reset Problem', message: _mapResetError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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
              const Text(
                'Reset Password',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the email associated with your account and we\'ll send you a verification code.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 48),
              _buildModernTextField(
                controller: _emailController,
                placeholder: 'Email Address',
                icon: CupertinoIcons.mail,
                keyboardType: TextInputType.emailAddress,
                isError: _emailError,
                onChanged: (_) {
                  if (_emailError) setState(() => _emailError = false);
                },
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  if (_emailController.text.trim().isNotEmpty && !_isLoading) {
                    _resetPassword();
                  }
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withAlpha(51), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : const Text(
                            'Send Code',
                            style: TextStyle(color: CupertinoColors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
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
    required String placeholder,
    required IconData icon,
    TextInputType? keyboardType,
    bool isError = false,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? CupertinoColors.systemRed : AppColors.divider, 
          width: isError ? 1.5 : 0.5
        ),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        onChanged: onChanged,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        placeholderStyle: const TextStyle(fontSize: 15, color: AppColors.textLight),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Icon(
            icon, 
            color: isError ? CupertinoColors.systemRed : AppColors.textLight, 
            size: 20
          ),
        ),
        decoration: null,
      ),
    );
  }
}
