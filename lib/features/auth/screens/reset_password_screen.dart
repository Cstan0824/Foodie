import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/features/auth/screens/login_screen.dart';
import 'package:taste_spot/core/widgets/feedback_dialog.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _isLoading = false;
  late final AuthRepository _authRepo = AuthRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _passFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      FeedbackDialog.show(context: context, title: 'New Password', message: 'Please enter a new password.');
      return;
    }
    if (password != confirm) {
      FeedbackDialog.show(context: context, title: 'Mismatch', message: 'Passwords do not match.');
      return;
    }
    if (password.length < 8) {
      FeedbackDialog.show(context: context, title: 'Security', message: 'Password must be at least 8 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepo.updatePassword(password);
      if (!mounted) return;
      FeedbackDialog.show(
        context: context,
        title: 'Success!',
        message: 'Your password has been updated. You can now sign in with your new password.',
        icon: CupertinoIcons.checkmark_shield_fill,
        iconColor: CupertinoColors.activeGreen,
        onConfirm: () {
          Navigator.of(context).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
      );
    } on AuthException catch (e) {
      FeedbackDialog.show(context: context, title: 'Failed', message: e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: const CupertinoNavigationBar(backgroundColor: CupertinoColors.white, border: null, middle: Text('Reset Password')),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(CupertinoIcons.lock_circle_fill, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text('Secure Your Account', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              const Text('Enter a new strong password below to regain access to your account.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: 48),

              _buildModernTextField(
                controller: _passwordController,
                focusNode: _passFocus,
                placeholder: 'New Password',
                icon: CupertinoIcons.lock_fill,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _confirmPasswordController,
                focusNode: _confirmFocus,
                placeholder: 'Confirm Password',
                icon: CupertinoIcons.checkmark_shield_fill,
                obscureText: true,
              ),

              const SizedBox(height: 48),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _updatePassword,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(27), boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 15, offset: const Offset(0, 6))]),
                  alignment: Alignment.center,
                  child: _isLoading ? const CupertinoActivityIndicator(color: CupertinoColors.white) : const Text('Update Password', style: TextStyle(color: CupertinoColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
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
  }) {
    final bool hasFocus = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: hasFocus ? CupertinoColors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasFocus ? AppColors.primary : Colors.transparent, width: 1.5),
        boxShadow: hasFocus ? [BoxShadow(color: AppColors.primary.withAlpha(15), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(icon, color: hasFocus ? AppColors.primary : AppColors.textLight, size: 20),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              focusNode: focusNode,
              placeholder: placeholder,
              obscureText: obscureText,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: null,
            ),
          ),
        ],
      ),
    );
  }
}
