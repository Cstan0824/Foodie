import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/features/auth/screens/login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  late final AuthRepository _authRepo = AuthRepository(Supabase.instance.client);

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      _showError('Please enter a new password.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authRepo.updatePassword(password);
      if (!mounted) return;
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Success'),
          content: const Text('Your password has been reset successfully. Please log in with your new password.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  CupertinoPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            )
          ],
        ),
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Failed to update password. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
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
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: null,
        middle: Text('Reset Password'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'New Password',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please enter your new password below.',
                style: TextStyle(fontSize: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 48),
              CupertinoTextField(
                controller: _passwordController,
                placeholder: 'New Password',
                obscureText: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: _confirmPasswordController,
                placeholder: 'Confirm Password',
                obscureText: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 48),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _updatePassword,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text('Update Password', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
