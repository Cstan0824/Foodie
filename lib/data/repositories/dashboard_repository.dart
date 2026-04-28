import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taste_spot/core/services/supabase_service.dart';

class DashboardStats {
  final int totalUsers;
  final int totalRestaurants;
  final int activeRestaurants;
  final int disabledRestaurants;
  final int pendingRestaurantApprovals;
  final int totalPosts;
  final int activePosts;
  final int pendingPosts;
  final int archivedPosts;
  final int blockedPosts;
  final int pendingReports;
  final int resolvedReports;
  final int blockedComments;

  const DashboardStats({
    required this.totalUsers,
    required this.totalRestaurants,
    required this.activeRestaurants,
    required this.disabledRestaurants,
    required this.pendingRestaurantApprovals,
    required this.totalPosts,
    required this.activePosts,
    required this.pendingPosts,
    required this.archivedPosts,
    required this.blockedPosts,
    required this.pendingReports,
    required this.resolvedReports,
    required this.blockedComments,
  });

  int get needsAttentionCount =>
      pendingReports + pendingRestaurantApprovals + pendingPosts;

  int get totalProblemContent => blockedPosts + blockedComments;
}

class DashboardActivityItem {
  static const String postType = 'post';
  static const String restaurantType = 'restaurant';
  static const String restaurantApprovalType = 'restaurantApproval';
  static const String reportType = 'report';
  static const String userType = 'user';
  static const String commentType = 'comment';

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final DateTime? createdAt;
  final String? targetId;

  const DashboardActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.targetId,
  });
}

class DashboardSummary {
  final DashboardStats stats;
  final List<DashboardActivityItem> recentActivities;

  const DashboardSummary({required this.stats, required this.recentActivities});
}

class DashboardRepository {
  DashboardRepository._();

  static final DashboardRepository instance = DashboardRepository._();

  Future<DashboardStats> fetchStats() async {
    final counts = await Future.wait<int>([
      _countAll('User'),
      _countAll('Restaurant'),
      _countWhere('Restaurant', (query) => query.eq('isDisabled', false)),
      _countWhere('Restaurant', (query) => query.eq('isDisabled', true)),
      _countWhere('RestaurantApproval', (query) => query.eq('status', 0)),
      _countAll('Post'),
      _countWhere(
        'Post',
        (query) => query
            .eq('isRemoved', false)
            .eq('isBlocked', false)
            .eq('isPending', false),
      ),
      _countWhere('Post', (query) => query.eq('isPending', true)),
      _countWhere(
        'Post',
        (query) => query.eq('isRemoved', true).eq('visible_to_owner', true),
      ),
      _countWhere('Post', (query) => query.eq('isBlocked', true)),
      _countWhere('Report', (query) => query.eq('status', 0)),
      _countWhere('Report', (query) => query.neq('status', 0)),
      _countWhere('Comment', (query) => query.eq('isBlocked', true)),
    ]);

    return DashboardStats(
      totalUsers: counts[0],
      totalRestaurants: counts[1],
      activeRestaurants: counts[2],
      disabledRestaurants: counts[3],
      pendingRestaurantApprovals: counts[4],
      totalPosts: counts[5],
      activePosts: counts[6],
      pendingPosts: counts[7],
      archivedPosts: counts[8],
      blockedPosts: counts[9],
      pendingReports: counts[10],
      resolvedReports: counts[11],
      blockedComments: counts[12],
    );
  }

  Future<List<DashboardActivityItem>> fetchRecentActivity({
    int limit = 10,
  }) async {
    final normalizedLimit = limit < 1 ? 1 : limit;

    final results = await Future.wait<List<DashboardActivityItem>>([
      _fetchRecentPosts(normalizedLimit),
      _fetchRecentRestaurants(normalizedLimit),
      _fetchRecentRestaurantApprovals(normalizedLimit),
      _fetchRecentReports(normalizedLimit),
      _fetchRecentUsers(normalizedLimit),
    ]);

    final allActivities = results.expand((items) => items).toList()
      ..sort((a, b) => _compareCreatedAtDesc(a.createdAt, b.createdAt));

    if (allActivities.length <= normalizedLimit) {
      return allActivities;
    }

    return allActivities.take(normalizedLimit).toList();
  }

  Future<DashboardSummary> fetchDashboardSummary({
    int activityLimit = 10,
  }) async {
    final results = await Future.wait<dynamic>([
      fetchStats(),
      fetchRecentActivity(limit: activityLimit),
    ]);

    return DashboardSummary(
      stats: results[0] as DashboardStats,
      recentActivities: results[1] as List<DashboardActivityItem>,
    );
  }

  Future<List<DashboardActivityItem>> _fetchRecentPosts(int limit) async {
    final response = await SupabaseService.client
        .from('Post')
        .select('post_Id, title, caption, created_At')
        .order('created_At', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => DashboardActivityItem(
            id: row['post_Id']?.toString() ?? '',
            targetId: row['post_Id']?.toString(),
            type: DashboardActivityItem.postType,
            title: 'New post submitted',
            subtitle: _postSubtitle(row),
            createdAt: _toDateTime(row['created_At']),
          ),
        )
        .toList();
  }

  Future<List<DashboardActivityItem>> _fetchRecentRestaurants(int limit) async {
    final response = await SupabaseService.client
        .from('Restaurant')
        .select('restaurant_Id, restaurant_name, created_At')
        .order('created_At', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => DashboardActivityItem(
            id: row['restaurant_Id']?.toString() ?? '',
            targetId: row['restaurant_Id']?.toString(),
            type: DashboardActivityItem.restaurantType,
            title: 'Restaurant added',
            subtitle:
                _firstNonBlank([row['restaurant_name']?.toString()]) ??
                'Unnamed restaurant',
            createdAt: _toDateTime(row['created_At']),
          ),
        )
        .toList();
  }

  Future<List<DashboardActivityItem>> _fetchRecentRestaurantApprovals(
    int limit,
  ) async {
    final response = await SupabaseService.client
        .from('RestaurantApproval')
        .select('approval_Id, restaurant_name, detectedAt')
        .eq('status', 0)
        .order('detectedAt', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => DashboardActivityItem(
            id: row['approval_Id']?.toString() ?? '',
            targetId: row['approval_Id']?.toString(),
            type: DashboardActivityItem.restaurantApprovalType,
            title: 'Restaurant approval pending',
            subtitle:
                _firstNonBlank([row['restaurant_name']?.toString()]) ??
                'Unnamed restaurant',
            createdAt: _toDateTime(row['detectedAt']),
          ),
        )
        .toList();
  }

  Future<List<DashboardActivityItem>> _fetchRecentReports(int limit) async {
    final response = await SupabaseService.client
        .from('Report')
        .select('report_Id, reason, created_At')
        .order('created_At', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => DashboardActivityItem(
            id: row['report_Id']?.toString() ?? '',
            targetId: row['report_Id']?.toString(),
            type: DashboardActivityItem.reportType,
            title: 'Report submitted',
            subtitle:
                _firstNonBlank([row['reason']?.toString()]) ??
                'No reason provided',
            createdAt: _toDateTime(row['created_At']),
          ),
        )
        .toList();
  }

  Future<List<DashboardActivityItem>> _fetchRecentUsers(int limit) async {
    final response = await SupabaseService.client
        .from('User')
        .select('user_Id, name, username, created_At')
        .order('created_At', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => DashboardActivityItem(
            id: row['user_Id']?.toString() ?? '',
            targetId: row['user_Id']?.toString(),
            type: DashboardActivityItem.userType,
            title: 'New user registered',
            subtitle:
                _firstNonBlank([
                  row['name']?.toString(),
                  row['username']?.toString(),
                ]) ??
                'Unnamed user',
            createdAt: _toDateTime(row['created_At']),
          ),
        )
        .toList();
  }

  Future<int> _countAll(String table) async {
    return SupabaseService.client.from(table).count(CountOption.exact);
  }

  Future<int> _countWhere(
    String table,
    PostgrestFilterBuilder<int> Function(PostgrestFilterBuilder<int> query)
    buildQuery,
  ) async {
    final query = buildQuery(
      SupabaseService.client.from(table).count(CountOption.exact),
    );
    return query;
  }

  String _postSubtitle(Map<String, dynamic> row) {
    return _firstNonBlank([
          row['title']?.toString(),
          _previewText(row['caption']?.toString()),
        ]) ??
        'Untitled post';
  }

  String? _previewText(String? value, {int maxLength = 80}) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 1).trimRight()}…';
  }

  String? _firstNonBlank(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  int _compareCreatedAtDesc(DateTime? left, DateTime? right) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }
}
