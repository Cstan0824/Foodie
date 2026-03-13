import 'package:flutter/cupertino.dart';
import '../../core/theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Walton G.');
    _bioController = TextEditingController(
        text: 'Food explorer | Bouldering enthusiast\nKL based · Discovering hidden gems 🍜');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: const Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        middle: const Text('Edit Profile'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Save',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.primary)),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 32),
              _EditField(label: 'Name', controller: _nameController),
              const SizedBox(height: 20),
              _EditField(label: 'Bio', controller: _bioController, maxLines: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
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
          const SizedBox(height: 12),
          const Text(
            'Change Photo',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const _EditField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          padding: const EdgeInsets.all(12),
          maxLines: maxLines,
          minLines: 1,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.tabBarBorder, width: 0.5),
          ),
        ),
      ],
    );
  }
}
