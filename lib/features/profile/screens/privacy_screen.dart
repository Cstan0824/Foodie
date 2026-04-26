import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/repositories/auth_repository.dart';
import 'package:taste_spot/core/widgets/feedback_dialog.dart';
import 'package:taste_spot/features/auth/screens/login_screen.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _isDeleting = false;
  late final AuthRepository _authRepo = AuthRepository(Supabase.instance.client);

  void _confirmDeleteAccount() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action is permanent and will remove all your posts, collections, and profile data. You cannot undo this.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _handleDeleteAccount();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    setState(() => _isDeleting = true);
    try {
      await _authRepo.deleteAccount();
      if (!mounted) return;
      
      FeedbackDialog.show(
        context: context,
        title: 'Account Deleted',
        message: 'Your account has been successfully removed. We\'re sorry to see you go!',
        icon: CupertinoIcons.trash_fill,
        onConfirm: () {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            CupertinoPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      FeedbackDialog.show(
        context: context,
        title: 'Deletion Failed',
        message: 'Something went wrong while deleting your account. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Privacy', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection(
                  title: 'Account Actions',
                  children: [
                    _buildTile(
                      title: 'Delete Account', 
                      isDestructive: true, 
                      onTap: _isDeleting ? () {} : _confirmDeleteAccount
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Deleting your account will permanently remove all your data, including posts, followers, and collections. This action cannot be reversed.',
                    style: TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.4),
                  ),
                ),
              ],
            ),
            if (_isDeleting)
              Container(
                color: CupertinoColors.white.withAlpha(150),
                child: const Center(child: CupertinoActivityIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTile({required String title, bool isDestructive = false, required VoidCallback onTap}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16, 
                  color: isDestructive ? CupertinoColors.systemRed : AppColors.textPrimary, 
                  fontWeight: FontWeight.w500
                ),
              ),
            ),
            if (!isDestructive) const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoSwitch(value: value, activeTrackColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}
