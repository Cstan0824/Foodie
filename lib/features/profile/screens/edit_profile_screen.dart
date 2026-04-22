import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/profile_model.dart';
import 'package:taste_spot/data/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final Profile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _usernameController = TextEditingController(
      text:
          widget.profile.username ??
          widget.profile.name.replaceAll(' ', '').toLowerCase(),
    );
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final repository = ProfileRepository(Supabase.instance.client);
      await repository.updateProfile(
        userId: widget.profile.userId,
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        middle: const Text('Edit Profile'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _saveProfile,
          child: _isSaving
              ? const CupertinoActivityIndicator()
              : const Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 24),
              _buildFormSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: ClipOval(
                child: Image.network(
                  'https://i.pravatar.cc/200?img=12',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    CupertinoIcons.person_fill,
                    size: 44,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: const Icon(
                  CupertinoIcons.camera_fill,
                  color: CupertinoColors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          _CupertinoEditRow(label: 'Name', controller: _nameController),
          const _CustomDivider(),
          _CupertinoEditRow(
            label: 'Username',
            controller: _usernameController,
            readOnly: true,
          ),
          const _CustomDivider(),
          _CupertinoEditRow(
            label: 'Bio',
            controller: _bioController,
            minLines: 2,
          ),
        ],
      ),
    );
  }
}

class _CustomDivider extends StatelessWidget {
  const _CustomDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 110),
      child: Container(height: 0.5, color: AppColors.divider),
    );
  }
}

class _CupertinoEditRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int minLines;
  final bool readOnly;

  const _CupertinoEditRow({
    required this.label,
    required this.controller,
    this.minLines = 1,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: minLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            child: Padding(
              padding: EdgeInsets.only(top: minLines > 1 ? 12.0 : 0),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              readOnly: readOnly,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minLines: minLines,
              maxLines: null, // Allow expanding
              style: TextStyle(
                fontSize: 15,
                color: readOnly
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
              decoration: const BoxDecoration(
                color: CupertinoColors
                    .transparent, // entirely flat like iOS native cell
              ),
              placeholder: label,
              placeholderStyle: const TextStyle(
                fontSize: 15,
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
