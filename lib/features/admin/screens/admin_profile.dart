import 'package:flutter/cupertino.dart';
import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/core/widgets/skeleton.dart';
import 'package:taste_spot/data/models/profile_model.dart';
import 'package:taste_spot/data/repositories/profile_repository.dart';
import 'package:taste_spot/features/auth/screens/login_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late Future<Profile?> _profileFuture;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<Profile?> _loadProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('No signed-in admin account found.');
    }

    final repo = ProfileRepository(SupabaseService.client);
    final profile = await repo.getProfile(userId);
    final imageUrl = await repo.getProfileImageUrl(userId);

    if (profile == null) return null;
    return Profile(
      userId: profile.userId,
      name: profile.name,
      username: profile.username,
      bio: profile.bio,
      role: profile.role,
      createdAt: profile.createdAt,
      imageUrl: imageUrl ?? profile.imageUrl,
    );
  }

  Future<void> _refresh() async {
    final future = _loadProfile();
    setState(() => _profileFuture = future);
    await future;
  }

  Future<void> _logout() async {
    setState(() => _isMenuOpen = false);
    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Admin Profile'),
              backgroundColor: AppColors.cardBackground,
              border: Border(
                bottom: BorderSide(color: AppColors.tabBarBorder, width: 0.5),
              ),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
                child: Icon(
                  _isMenuOpen ? CupertinoIcons.xmark : CupertinoIcons.bars,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
            ),
            CupertinoSliverRefreshControl(onRefresh: _refresh),
            SliverToBoxAdapter(
              child: FutureBuilder<Profile?>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _AdminProfileSkeleton();
                  }

                  if (snapshot.hasError) {
                    return _AdminProfileError(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  final profile = snapshot.data;
                  if (profile == null) {
                    return _AdminProfileError(
                      message: 'Profile record was not found.',
                      onRetry: _refresh,
                    );
                  }

                  return _AdminProfileContent(profile: profile);
                },
              ),
            ),
          ],
        ),
        if (_isMenuOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isMenuOpen = false),
              child: Container(color: CupertinoColors.black.withAlpha(12)),
            ),
          ),
        _AdminProfileMenu(isOpen: _isMenuOpen, onLogout: _logout),
      ],
    );
  }
}

class _AdminProfileMenu extends StatelessWidget {
  final bool isOpen;
  final Future<void> Function() onLogout;

  const _AdminProfileMenu({required this.isOpen, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      top: isOpen ? MediaQuery.of(context).padding.top + 48 : 28,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: isOpen ? 1 : 0,
        child: IgnorePointer(
          ignoring: !isOpen,
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withAlpha(24),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _AdminMenuAction(
              label: 'Logout',
              icon: CupertinoIcons.power,
              isDestructive: true,
              onTap: onLogout,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminMenuAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final Future<void> Function() onTap;

  const _AdminMenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? CupertinoColors.systemRed
        : AppColors.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color.withAlpha(210)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminProfileContent extends StatelessWidget {
  final Profile profile;

  const _AdminProfileContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    final username = _displayUsername(profile.username);
    final bio = _displayBio(profile.bio);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdminIdentityCard(profile: profile, username: username, bio: bio),
          const SizedBox(height: 20),
          const _SectionTitle('Account Details'),
          const SizedBox(height: 12),
          _ProfileInfoCard(
            rows: [
              _InfoRowData(
                icon: CupertinoIcons.person_fill,
                label: 'Name',
                value: profile.name,
              ),
              _InfoRowData(
                icon: CupertinoIcons.at,
                label: 'Username',
                value: username,
              ),
              _InfoRowData(
                icon: CupertinoIcons.shield_fill,
                label: 'Access',
                value: _formatRole(profile.role),
              ),
              _InfoRowData(
                icon: CupertinoIcons.calendar,
                label: 'Created',
                value: _formatDate(profile.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Bio'),
          const SizedBox(height: 12),
          _BioCard(text: bio),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AdminIdentityCard extends StatelessWidget {
  final Profile profile;
  final String username;
  final String bio;

  const _AdminIdentityCard({
    required this.profile,
    required this.username,
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdminAvatar(imageUrl: profile.imageUrl, name: profile.name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _AdminBadge(),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Text(
              bio,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;

  const _AdminAvatar({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 76,
        height: 76,
        color: AppColors.surface,
        child: url == null || url.isEmpty
            ? _AvatarFallback(name: name)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _AvatarFallback(name: name),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;

  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withAlpha(55), width: 0.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.shield_fill, size: 12, color: AppColors.primary),
          SizedBox(width: 4),
          Text(
            'Admin',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final List<_InfoRowData> rows;

  const _ProfileInfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final isLast = i == rows.length - 1;
          return Column(
            children: [
              _ProfileInfoRow(data: rows[i]),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Container(height: 0.5, color: AppColors.divider),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _InfoRowData {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _ProfileInfoRow extends StatelessWidget {
  final _InfoRowData data;

  const _ProfileInfoRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              data.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BioCard extends StatelessWidget {
  final String text;

  const _BioCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _AdminProfileSkeleton extends StatelessWidget {
  const _AdminProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IdentityCardSkeleton(),
          SizedBox(height: 20),
          _SectionTitle('Account Details'),
          SizedBox(height: 12),
          _InfoCardSkeleton(),
          SizedBox(height: 20),
          _SectionTitle('Bio'),
          SizedBox(height: 12),
          _BioSkeleton(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _IdentityCardSkeleton extends StatelessWidget {
  const _IdentityCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 76, height: 76, borderRadius: 18),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 150, height: 22, borderRadius: 5),
                    SizedBox(height: 9),
                    Skeleton(width: 110, height: 13, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Skeleton(width: double.infinity, height: 54, borderRadius: 12),
        ],
      ),
    );
  }
}

class _InfoCardSkeleton extends StatelessWidget {
  const _InfoCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: List.generate(4, (i) {
          final isLast = i == 3;
          return Column(
            children: [
              const _InfoRowSkeleton(),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Container(height: 0.5, color: AppColors.divider),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _InfoRowSkeleton extends StatelessWidget {
  const _InfoRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Skeleton(width: 32, height: 32, borderRadius: 8),
          SizedBox(width: 12),
          Skeleton(width: 76, height: 13, borderRadius: 4),
          Spacer(),
          Skeleton(width: 112, height: 13, borderRadius: 4),
        ],
      ),
    );
  }
}

class _BioSkeleton extends StatelessWidget {
  const _BioSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: double.infinity, height: 13, borderRadius: 4),
          SizedBox(height: 8),
          Skeleton(width: 230, height: 13, borderRadius: 4),
        ],
      ),
    );
  }
}

class _AdminProfileError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _AdminProfileError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: Color(0xFFFF9500),
              size: 30,
            ),
            const SizedBox(height: 12),
            const Text(
              'Admin profile could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _displayUsername(String? username) {
  final value = username?.trim();
  if (value == null || value.isEmpty) return 'No username';
  return value.startsWith('@') ? value : '@$value';
}

String _displayBio(String? bio) {
  final value = bio?.trim();
  if (value == null || value.isEmpty) {
    return 'No bio added for this admin account.';
  }
  return value;
}

String _formatRole(String role) {
  final value = role.trim();
  if (value.isEmpty) return 'Admin';
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
