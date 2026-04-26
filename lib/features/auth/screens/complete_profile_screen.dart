import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/main.dart'; // To navigate to Home on completion

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  late final AuthRepository _authRepo = AuthRepository(
    Supabase.instance.client,
  );
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  bool _usernameError = false;
  String? _currentUserId;
  Timer? _usernameDebounce;

  @override
  void initState() {
    super.initState();
    // Pre-fill username from the partial profile we just saved
    _loadInitialProfileData();
  }

  Future<void> _loadInitialProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _currentUserId = user.id;
      try {
        final response = await Supabase.instance.client
            .from('User')
            .select()
            .eq('user_Id', user.id)
            .maybeSingle();

        final existingUsername = response?['username'] as String?;
        final existingName = response?['name'] as String?;

        if (mounted &&
            existingUsername != null &&
            existingUsername.isNotEmpty) {
          _usernameController.text = existingUsername;
          _onUsernameChanged(existingUsername);
        } else if (mounted && existingName != null) {
          // Fall back for older rows created before username existed.
          if (!existingName.contains('New Foodie')) {
            _usernameController.text = existingName;
            _onUsernameChanged(existingName);
          }
        }
      } catch (e) {
        print('Error pre-filling profile: $e');
      }
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
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
        final available = await _authRepo.isUsernameAvailable(
          username,
          excludingUserId: _currentUserId,
        );
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

  String _mapUserModuleError(Object error) {
    if (error is PostgrestException) {
      final detailsText = error.details?.toString() ?? '';
      if (error.code == '23505' &&
          (error.message.contains('User_username_key') ||
              detailsText.contains('(username)='))) {
        return 'This username is already taken. Please choose another one.';
      }
      return 'Could not update your profile right now. Please try again.';
    }

    final message = error.toString();
    if (message.contains('USERNAME_TAKEN')) {
      return 'This username is already taken. Please choose another one.';
    }

    return 'Could not update your profile right now. Please try again.';
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

  Future<void> _completeProfile() async {
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    setState(() {
      _usernameError = username.isEmpty;
    });

    if (username.isEmpty) {
      _showAlert('Username Required', 'Please enter a username to continue.');
      return;
    }

    if (_isCheckingUsername) {
      _showAlert(
        'Checking Username',
        'Please wait while we verify your username.',
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showAlert(
        'Update Failed',
        'No authenticated user found. Please log in again.',
      );
      return;
    }

    final available = await _authRepo.isUsernameAvailable(
      username,
      excludingUserId: user.id,
    );
    if (!available) {
      if (mounted) {
        setState(() => _isUsernameAvailable = false);
      }
      _showAlert(
        'Username Taken',
        'This username is already taken. Please choose another one.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update the profile row that was created during the listener
      await Supabase.instance.client
          .from('User')
          .update({'username': username, 'bio': bio.isEmpty ? null : bio})
          .eq('user_Id', user.id);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _showAlert('Update Failed', _mapUserModuleError(e));
    } catch (e) {
      if (!mounted) return;
      _showAlert('Update Failed', _mapUserModuleError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        border: null,
        middle: const Text('Complete Your Profile'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Welcome to TasteSpot!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "You're almost done. What should we call you flavor-hunter?",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),

              // Username Field
              const Text(
                'Username',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _usernameController,
                onChanged: (v) {
                  _onUsernameChanged(v);
                  if (_usernameError) setState(() => _usernameError = false);
                },
                padding: const EdgeInsets.all(16),
                placeholder: 'e.g. burger_master',
                placeholderStyle: const TextStyle(color: AppColors.textLight),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _usernameError ? CupertinoColors.systemRed : AppColors.divider,
                    width: _usernameError ? 1.5 : 1,
                  ),
                ),
              ),
              if (_isCheckingUsername)
                const Padding(
                  padding: EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    'Checking username...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else if (_isUsernameAvailable == false)
                const Padding(
                  padding: EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    'Username is already taken',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemRed,
                    ),
                  ),
                )
              else if (_isUsernameAvailable == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    'Username is available',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.activeGreen,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Bio Field
              const Text(
                'Bio (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _bioController,
                padding: const EdgeInsets.all(16),
                placeholder: 'Tell us your favorite foods...',
                placeholderStyle: const TextStyle(color: AppColors.textLight),
                minLines: 3,
                maxLines: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
              ),
              const SizedBox(height: 48),

              // Save Button
              if (_isLoading)
                const Center(child: CupertinoActivityIndicator())
              else
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _completeProfile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Finish Setup',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
}
