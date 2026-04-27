import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';

enum OTPType { signup, recovery }

class VerifyOTPScreen extends StatefulWidget {
  final String email;
  final OTPType type;

  const VerifyOTPScreen({
    super.key,
    required this.email,
    required this.type,
  });

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final List<TextEditingController> _controllers = List.generate(8, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(8, (_) => FocusNode());
  bool _isLoading = false;
  late final AuthRepository _authRepo = AuthRepository(Supabase.instance.client);

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 7) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _verifyOTP();
    }
  }

  Future<void> _verifyOTP() async {
    final token = _controllers.map((c) => c.text).join();
    if (token.length < 8) return;

    setState(() => _isLoading = true);

    try {
      if (widget.type == OTPType.signup) {
        await _authRepo.verifySignUpOtp(email: widget.email, token: token);
      } else {
        await _authRepo.verifyRecoveryOtp(email: widget.email, token: token);
      }
      
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    try {
      await _authRepo.resendOtp(
        email: widget.email,
        type: widget.type == OTPType.signup ? OtpType.signup : OtpType.recovery,
      );
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Code Sent'),
            content: const Text('A new 8-digit verification code has been sent to your email.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _showError('Failed to resend code: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Verification Error'),
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
        middle: Text('Verify OTP'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Verify Account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 8-digit code sent to ${widget.email}',
                style: const TextStyle(fontSize: 15, color: AppColors.textLight, height: 1.4),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(8, (index) => _buildOTPBox(index)),
              ),
              const SizedBox(height: 48),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _verifyOTP,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : const Text('Verify', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: CupertinoButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: const Text('Resend Code', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOTPBox(int index) {
    return Container(
      width: 38,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _focusNodes[index].hasFocus ? AppColors.primary : AppColors.divider, width: 1.5),
      ),
      child: CupertinoTextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: null,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        onChanged: (v) => _onChanged(v, index),
      ),
    );
  }
}
