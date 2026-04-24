import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';

class FeedbackDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final List<Widget> actions;

  const FeedbackDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.actions,
  });

  static void show({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = CupertinoIcons.exclamationmark_circle_fill,
    Color iconColor = CupertinoColors.systemRed,
    String buttonText = 'Dismiss',
    VoidCallback? onConfirm,
  }) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => FeedbackDialog(
        title: title,
        message: message,
        icon: icon,
        iconColor: iconColor,
        actions: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E5E7), width: 0.5)),
            ),
            child: CupertinoButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm?.call();
              },
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: CupertinoColors.black.withAlpha(40), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 40),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  decoration: TextDecoration.none,
                  fontFamily: '.SF Pro Display',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.4,
                  decoration: TextDecoration.none,
                  fontFamily: '.SF Pro Text',
                ),
              ),
            ),
            const SizedBox(height: 32),
            ...actions,
          ],
        ),
      ),
    );
  }
}
