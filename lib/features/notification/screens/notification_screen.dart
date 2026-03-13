import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/theme/app_theme.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy notification data
    final notifications = [
      {
        'type': 'like',
        'user': 'Sarah Chen',
        'avatar': 'https://i.pravatar.cc/150?img=1',
        'time': '2h ago',
        'content': 'liked your post "Best matcha in KL"',
        'postImage': 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?q=80&w=200&auto=format&fit=crop',
        'isRead': false,
      },
      {
        'type': 'comment',
        'user': 'Mike Wong',
        'avatar': 'https://i.pravatar.cc/150?img=11',
        'time': '5h ago',
        'content': 'commented: "I need to try this place!"',
        'postImage': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=200&auto=format&fit=crop',
        'isRead': false,
      },
      {
        'type': 'follow',
        'user': 'Emma Davis',
        'avatar': 'https://i.pravatar.cc/150?img=5',
        'time': '1d ago',
        'content': 'started following you',
        'postImage': null,
        'isRead': true,
      },
      {
        'type': 'like',
        'user': 'Alex K.',
        'avatar': 'https://i.pravatar.cc/150?img=8',
        'time': '2d ago',
        'content': 'liked your post "Hidden gem in PJ"',
        'postImage': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?q=80&w=200&auto=format&fit=crop',
        'isRead': true,
      },
      {
        'type': 'system',
        'user': 'Taste Spot',
        'avatar': null, // System icon
        'time': '1w ago',
        'content': 'Welcome to Taste Spot! Start discovering great food today.',
        'postImage': null,
        'isRead': true,
      },
    ];

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
      ),
      child: SafeArea(
        child: notifications.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => Container(
                  height: 0.5,
                  color: AppColors.divider,
                  margin: const EdgeInsets.only(left: 72), // Indent after avatar
                ),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return _buildNotificationTile(notif);
                },
              ),
      ),
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
            decoration: BoxDecoration(
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

  Widget _buildNotificationTile(Map<String, dynamic> notif) {
    final bool isRead = notif['isRead'] as bool;
    final String type = notif['type'] as String;

    return Container(
      color: isRead ? CupertinoColors.white : AppColors.primary.withAlpha(10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ──
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  image: notif['avatar'] != null
                      ? DecorationImage(
                          image: NetworkImage(notif['avatar'] as String),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: notif['avatar'] == null
                    ? const Icon(CupertinoIcons.flame_fill, color: AppColors.primary)
                    : null,
              ),
              // Tiny badge icon for type
              Positioned(
                bottom: -2,
                right: -2,
                child: _buildTypeBadge(type),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // ── Content ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    children: [
                      TextSpan(
                        text: '${notif['user']} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: notif['content'] as String,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notif['time'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Right Side (Post Image or Follow Button) ──
          if (notif['postImage'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                notif['postImage'] as String,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            )
          else if (type == 'follow')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Follow',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
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
