import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/utils/app_time.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/repositories/notification_repository.dart';
import 'package:taste_spot/features/post/screens/post_detail_screen.dart';
import 'package:taste_spot/features/collection/screens/collection_detail_screen.dart';
import 'package:taste_spot/data/models/collection_model.dart';
import 'package:taste_spot/data/repositories/post_repository.dart';
import 'package:taste_spot/data/repositories/collection_repository.dart';

class NotifItem {
  final String id;
  final String content;
  final String? redirectTo;
  final DateTime createdAt;
  final String? avatarUrl;
  bool isRead;

  NotifItem({
    required this.id,
    required this.content,
    this.redirectTo,
    required this.createdAt,
    this.avatarUrl,
    required this.isRead,
  });

  factory NotifItem.fromJson(Map<String, dynamic> j) {
    final sender = j['sender'] as Map<String, dynamic>?;

    // Parse avatar URL using the project standard: join on UserImage
    String? avatar;
    if (sender != null) {
      final userImages = sender['UserImage'];
      if (userImages != null) {
        if (userImages is List && userImages.isNotEmpty) {
          avatar = userImages[0]['image_url'] as String?;
        } else if (userImages is Map) {
          avatar = userImages['image_url'] as String?;
        }
      }
    }

    return NotifItem(
      id: j['id'] as String,
      content: (j['content'] as String?) ?? '',
      redirectTo: j['redirect_To'] as String?,
      createdAt: AppTime.parseUtc(j['created_At']) ?? AppTime.nowUtc(),
      avatarUrl: avatar,
      isRead: (j['isRead'] as bool?) ?? false,
    );
  }

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
  final NotificationRepository _notifRepo = NotificationRepository(
    Supabase.instance.client,
  );
  List<NotifItem> _notifications = [];
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

      print('📡 Fetching notifications for user: $userId...');
      final response = await _notifRepo.fetchNotifications(userId);
      print('✅ Notifications fetched successfully. Count: ${response.length}');
      if (response.isNotEmpty) {
        print('DEBUG: First notification JSON: ${response.first}');
      }

      final items = response.map((e) => NotifItem.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
        });
        _markAllRead(userId);
      }
    } catch (e) {
      print('❌ [NotificationScreen._loadNotifications] ERROR: $e');
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
      await _notifRepo.markAllAsRead(userId);
      if (mounted) {
        setState(() {
          for (final n in _notifications) {
            n.isRead = true;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _onNotifTap(NotifItem notif) async {
    final redirect = notif.redirectTo;
    if (redirect == null || redirect.isEmpty) return;

    try {
      final parts = redirect.split(':');
      if (parts.length < 2) return;

      final type = parts[0].toLowerCase();
      final id = parts[1];

      if (type == 'post') {
        final post = await PostRepository.instance.fetchPostById(id);
        if (post != null && mounted) {
          Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => PostDetailScreen(post: post)),
          );
        }
      } else if (type == 'collection') {
        final collRepo = CollectionRepository(Supabase.instance.client);
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId == null) return;

        // Fetch collections to find the matching one
        final collections = await collRepo.getUserCollections(currentUserId);
        Collection? collection;
        try {
          collection = collections.firstWhere((c) => c.collectionId == id);
        } catch (_) {
          // If not in own, try shared
          final shared = await collRepo.getSharedCollections(currentUserId);
          try {
            collection = shared.firstWhere((c) => c.collectionId == id);
          } catch (_) {}
        }

        final Collection? finalCollection = collection;
        if (finalCollection != null && mounted) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) =>
                  CollectionDetailScreen(collection: finalCollection),
            ),
          );
        }
      }
    } catch (e) {
      print('Error navigating to notification target: $e');
    }
  }

  Map<String, List<NotifItem>> _groupNotifications(List<NotifItem> items) {
    final groups = <String, List<NotifItem>>{};
    final now = AppTime.nowGmt8();

    for (final item in items) {
      final diff = now.difference(AppTime.toGmt8(item.createdAt)).inDays;
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
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            fontSize: 18,
          ),
        ),
        leading: CupertinoNavigationBarBackButton(
          color: AppColors.textPrimary,
          onPressed: () =>
              Navigator.of(context).pop(true), // Return true to trigger refresh
        ),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _NotificationSkeleton();

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.wifi_exclamationmark,
              size: 40,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            CupertinoButton(
              onPressed: _loadNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.bell_slash,
              size: 48,
              color: AppColors.surface,
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final groups = _groupNotifications(_notifications);
    final groupTitles = [
      'Today',
      'Yesterday',
      'This Week',
      'This Month',
      'Earlier',
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _loadNotifications),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ...items.map((item) => _buildNotifTile(item)),
              ],
            );
          }, childCount: groupTitles.length),
        ),
      ],
    );
  }

  Widget _buildNotifTile(NotifItem notif) {
    return GestureDetector(
      onTap: () => _onNotifTap(notif),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: notif.isRead
              ? CupertinoColors.white
              : AppColors.primary.withAlpha(5),
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: notif.content,
                          style: TextStyle(
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notif.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!notif.isRead)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarStack(NotifItem notif) {
    IconData icon;
    Color color;
    switch (notif.inferredType) {
      case 'like':
        icon = CupertinoIcons.heart_fill;
        color = AppColors.primary;
        break;
      case 'comment':
        icon = CupertinoIcons.chat_bubble_fill;
        color = CupertinoColors.activeBlue;
        break;
      case 'follow':
        icon = CupertinoIcons.person_fill;
        color = CupertinoColors.activeGreen;
        break;
      default:
        icon = CupertinoIcons.bell_fill;
        color = AppColors.textSecondary;
    }

    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: (notif.avatarUrl != null && notif.avatarUrl!.isNotEmpty)
                ? Image.network(
                    notif.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      CupertinoIcons.person_fill,
                      color: AppColors.textLight,
                      size: 28,
                    ),
                  )
                : const Icon(
                    CupertinoIcons.person_fill,
                    color: AppColors.textLight,
                    size: 28,
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
    final diff = AppTime.differenceFromNowGmt8(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return AppTime.formatNumericDayMonth(dt);
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
