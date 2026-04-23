import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';

// ─────────────────────────────────────────────
// Lightweight notification model (matches DB schema)
// ─────────────────────────────────────────────
class _NotifItem {
  final String id;
  final String content;
  final String? redirectTo;
  final DateTime createdAt;
  bool isRead;

  _NotifItem({
    required this.id,
    required this.content,
    this.redirectTo,
    required this.createdAt,
    required this.isRead,
  });

  factory _NotifItem.fromJson(Map<String, dynamic> j) => _NotifItem(
        id: j['id'] as String,
        content: (j['content'] as String?) ?? '',
        redirectTo: j['redirect_To'] as String?,
        createdAt: DateTime.parse(j['created_At'] as String),
        isRead: (j['isRead'] as bool?) ?? false,
      );

  /// Infers notification type from the content text for badge icon.
  String get inferredType {
    final c = content.toLowerCase();
    if (c.contains('liked') || c.contains('like')) return 'like';
    if (c.contains('comment')) return 'comment';
    if (c.contains('follow')) return 'follow';
    return 'system';
  }
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<_NotifItem> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('Notification')
          .select('id, content, redirect_To, created_At, isRead')
          .eq('user_id', userId)
          .order('created_At', ascending: false)
          .limit(50);

      final items = (response as List<dynamic>)
          .map((e) => _NotifItem.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
        });
        // Mark all unread as read in the background
        _markAllRead(userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllRead(String userId) async {
    try {
      await Supabase.instance.client
          .from('Notification')
          .update({'isRead': true})
          .eq('user_id', userId)
          .eq('isRead', false);

      // Reflect change locally without a reload
      if (mounted) {
        setState(() {
          for (final n in _notifications) {
            n.isRead = true;
          }
        });
      }
    } catch (_) {
      // Non-critical — silently ignore
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
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
        middle: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: CupertinoNavigationBarBackButton(
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loadNotifications,
          child: const Icon(
            CupertinoIcons.arrow_clockwise,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      child: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Failed to load notifications',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: _loadNotifications,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => Container(
        height: 0.5,
        color: AppColors.divider,
        margin: const EdgeInsets.only(left: 72),
      ),
      itemBuilder: (_, i) => _buildTile(_notifications[i]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.bell_slash,
              size: 32,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'When you get likes, comments,\nor followers, they\'ll show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(_NotifItem notif) {
    return Container(
      color: notif.isRead
          ? CupertinoColors.white
          : AppColors.primary.withAlpha(10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon badge ──
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.flame_fill,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: _buildTypeBadge(notif.inferredType),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // ── Content ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: notif.isRead
                        ? FontWeight.normal
                        : FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _timeAgo(notif.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),

          // ── Unread dot ──
          if (!notif.isRead) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'like':
        icon = CupertinoIcons.heart_fill;
        color = AppColors.primary;
      case 'comment':
        icon = CupertinoIcons.chat_bubble_fill;
        color = CupertinoColors.activeBlue;
      case 'follow':
        icon = CupertinoIcons.person_fill;
        color = CupertinoColors.activeGreen;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: CupertinoColors.white, width: 1.5),
      ),
      child: Icon(icon, size: 10, color: CupertinoColors.white),
    );
  }
}
