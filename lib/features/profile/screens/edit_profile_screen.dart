import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/profile_model.dart';
import 'package:taste_spot/data/repositories/profile_repository.dart';
import 'package:taste_spot/core/services/account_service.dart';
import 'dart:convert';
import 'dart:typed_data';

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
  String? _profileImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _usernameController = TextEditingController(text: widget.profile.username ?? '');
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      final repository = ProfileRepository(Supabase.instance.client);
      final url = await repository.getProfileImageUrl(widget.profile.userId);
      if (mounted) {
        setState(() {
          _profileImageUrl = url;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final repository = ProfileRepository(Supabase.instance.client);
      await repository.updateProfile(
        userId: widget.profile.userId,
        name: name,
        bio: _bioController.text.trim(),
      );

      // Sync with local accounts
      final session = Supabase.instance.client.auth.currentSession;
      await AccountService.saveAccount(
        userId: widget.profile.userId,
        name: name,
        username: widget.profile.username,
        avatarUrl: _profileImageUrl,
        sessionJson: session != null ? jsonEncode(session.toJson()) : null,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(ctx))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        ),
        middle: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _saveProfile,
          child: _isSaving
              ? const CupertinoActivityIndicator()
              : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 12),
              _buildSectionTitle('ACCOUNT INFORMATION'),
              _buildFormSection(),
              const SizedBox(height: 24),
              _buildSectionTitle('ABOUT ME'),
              _buildBioSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withAlpha(40), width: 1.5),
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
                    child: ClipOval(
                      child: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                          ? Image.network(
                              _profileImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.person_fill, size: 50, color: AppColors.textLight),
                            )
                          : const Icon(CupertinoIcons.person_fill, size: 50, color: AppColors.textLight),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: CupertinoColors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.camera_fill, color: CupertinoColors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Change Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _ModernEditField(
            label: 'Name',
            controller: _nameController,
            placeholder: 'Your display name',
          ),
          const SizedBox(height: 16),
          _ModernEditField(
            label: 'Username',
            controller: _usernameController,
            readOnly: true,
            placeholder: 'username',
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: CupertinoTextField(
              controller: _bioController,
              placeholder: 'Write a short bio...',
              maxLines: 5,
              padding: EdgeInsets.zero,
              decoration: null,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.5),
              placeholderStyle: const TextStyle(fontSize: 15, color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: _bioController,
            builder: (context, value, child) {
              final count = value.text.length;
              return Text(
                '$count / 100',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: count > 100 ? CupertinoColors.destructiveRed : AppColors.textLight,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModernEditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final bool readOnly;

  const _ModernEditField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: readOnly ? AppColors.surface.withAlpha(120) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            readOnly: readOnly,
            padding: EdgeInsets.zero,
            decoration: null,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: readOnly ? AppColors.textLight : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
