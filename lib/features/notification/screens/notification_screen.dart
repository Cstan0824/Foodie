import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';

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

  String get inferredType {
    final c = content.toLowerCase();
    if (c.contains('liked') || c.contains('like')) return 'like';
    if (c.contains('comment')) return 'comment';
    if (c.contains('follow')) return 'follow';
    return 'system';
  }
}

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
          .limit(100);

      final items = (response as List<dynamic>)
          .map((e) => _NotifItem.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
        });
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

      if (mounted) {
        setState(() {
          for (final n in _notifications) {
            n.isRead = true;
          }
        });
      }
    } catch (_) {}
  }

  Map<String, List<_NotifItem>> _groupNotifications(List<_NotifItem> items) {
    final groups = <String, List<_NotifItem>>{};
    final now = DateTime.now();

    for (final item in items) {
      final diff = now.difference(item.createdAt).inDays;
      String group;
      if (diff == 0) {
        group = 'Today';
      } else if (diff == 1) {
        group = 'Yesterday';
      } else if (diff < 7) {
        group = 'This Week';
      } else if (diff < 30) {
        group = 'This Month';
      } else {
        group = 'Earlier';
      }

      groups.putIfAbsent(group, () => []).add(item);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: null,
        middle: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8, fontSize: 18),
        ),
        leading: CupertinoNavigationBarBackButton(
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _NotificationSkeleton();

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.wifi_exclamationmark, size: 40, color: AppColors.textLight),
            const SizedBox(height: 12),
            const Text('Something went wrong', style: TextStyle(fontWeight: FontWeight.w600)),
            CupertinoButton(onPressed: _loadNotifications, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.bell_slash, size: 48, color: AppColors.surface),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final groups = _groupNotifications(_notifications);
    final groupTitles = ['Today', 'Yesterday', 'This Week', 'This Month', 'Earlier'];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _loadNotifications),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final title = groupTitles[i];
              final items = groups[title];
              if (items == null || items.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                  ),
                  ...items.map((item) => _buildNotifTile(item)),
                ],
              );
            },
            childCount: groupTitles.length,
          ),
        ),
      ],
    );
  }

  Widget _buildNotifTile(_NotifItem notif) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: notif.isRead ? CupertinoColors.white : AppColors.primary.withAlpha(5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarStack(notif),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                    children: [
                      TextSpan(
                        text: notif.content,
                        style: TextStyle(fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700, letterSpacing: -0.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _timeAgo(notif.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (!notif.isRead)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 6, left: 8),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack(_NotifItem notif) {
    IconData icon;
    Color color;
    switch (notif.inferredType) {
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
        icon = CupertinoIcons.bell_fill;
        color = AppColors.textSecondary;
    }

    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
          child: ClipOval(
            child: Image.network(
              'https://i.pravatar.cc/200?u=${notif.id}',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(CupertinoIcons.person_fill, color: AppColors.textLight, size: 28),
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: CupertinoColors.white, width: 2),
            ),
            child: Icon(icon, size: 9, color: CupertinoColors.white),
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.only(top: 16),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const SkeletonCircle(size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Skeleton(width: double.infinity, height: 16),
                  const SizedBox(height: 8),
                  Skeleton(width: 80, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
