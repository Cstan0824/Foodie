import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/comment_model.dart';
import 'package:taste_spot/data/models/post_model.dart';
import 'package:taste_spot/data/repositories/comment_repository.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';

class ReportFormScreen extends StatefulWidget {
  final PostModel? post;
  final CommentModel? comment;

  const ReportFormScreen({super.key, this.post, this.comment})
    : assert(
        post != null || comment != null,
        'Must provide either post or comment',
      );

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _detailsController = TextEditingController();
  String _selectedReason = 'Spam';
  bool _isSubmitting = false;

  final _reasons = [
    'Spam',
    'Offensive Language',
    'Misinformation',
    'Harassment',
  ];

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    try {
      final currentUserId = SupabaseService.requireCurrentUserId();
      final details = _detailsController.text.trim();

      if (widget.post != null) {
        await PostRepository.instance.reportPost(
          postId: widget.post!.id,
          userId: currentUserId,
          reason: _selectedReason,
          details: details.isNotEmpty ? details : null,
        );
      } else if (widget.comment != null) {
        await CommentRepository.instance.reportComment(
          commentId: widget.comment!.commentId,
          userId: currentUserId,
          reason: _selectedReason,
          details: details.isNotEmpty ? details : null,
        );
      }

      if (mounted) {
        await showCupertinoDialog(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Report Received'),
            content: const Text(
              'Thank you for your report. Our team will review it shortly.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showCupertinoDialog(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.post != null ? 'Report Post' : 'Report Comment';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: _isSubmitting
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _submitReport,
                child: const Text(
                  'Submit',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8, top: 16),
              child: Text(
                'REASON',
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: List.generate(_reasons.length, (i) {
                  final reason = _reasons[i];
                  final isLast = i == _reasons.length - 1;
                  final isSelected = _selectedReason == reason;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedReason = reason),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : const Border(
                                bottom: BorderSide(
                                  color: AppColors.divider,
                                  width: 0.5,
                                ),
                              ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            reason,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              CupertinoIcons.checkmark_alt,
                              color: AppColors.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8, top: 24),
              child: Text(
                'ADDITIONAL DETAILS (OPTIONAL)',
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CupertinoTextField(
                controller: _detailsController,
                placeholder: 'Please provide more context...',
                minLines: 4,
                maxLines: 6,
                padding: const EdgeInsets.all(16),
                decoration: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
