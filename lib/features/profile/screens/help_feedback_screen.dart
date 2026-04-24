import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';

class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Help & Feedback', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 12),
            const Text(
              'How can we help?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            _buildHelpOption(
              icon: CupertinoIcons.question_circle,
              title: 'Help Center',
              subtitle: 'Read our guides and FAQs',
              onTap: () {},
            ),
            _buildHelpOption(
              icon: CupertinoIcons.exclamationmark_bubble,
              title: 'Report a Problem',
              subtitle: 'Found a bug or something broken?',
              onTap: () {},
            ),
            _buildHelpOption(
              icon: CupertinoIcons.chat_bubble_2,
              title: 'Contact Us',
              subtitle: 'Chat with our support team',
              onTap: () {},
            ),
            _buildHelpOption(
              icon: CupertinoIcons.star,
              title: 'Feature Request',
              subtitle: 'Tell us how to make Taste Spot better',
              onTap: () {},
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: const Column(
                children: [
                  Icon(CupertinoIcons.heart_fill, color: AppColors.primary, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Enjoying Taste Spot?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'We\'d love to hear your feedback in the App Store!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
