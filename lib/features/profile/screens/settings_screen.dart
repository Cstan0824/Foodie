import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection(
              title: 'Account',
              children: [
                _buildTile(icon: CupertinoIcons.person, title: 'Account Information', onTap: () {}),
                _buildTile(icon: CupertinoIcons.shield, title: 'Security', onTap: () {}),
                _buildTile(icon: CupertinoIcons.bell, title: 'Notifications', onTap: () {}),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Preferences',
              children: [
                _buildTile(icon: CupertinoIcons.eye, title: 'Appearance', onTap: () {}),
                _buildTile(icon: CupertinoIcons.globe, title: 'Language', onTap: () {}),
                _buildTile(icon: CupertinoIcons.trash, title: 'Clear Cache', onTap: () {}),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'About',
              children: [
                _buildTile(icon: CupertinoIcons.info, title: 'About Taste Spot', onTap: () {}),
                _buildTile(icon: CupertinoIcons.doc_text, title: 'Terms of Service', onTap: () {}),
              ],
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

  Widget _buildTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
