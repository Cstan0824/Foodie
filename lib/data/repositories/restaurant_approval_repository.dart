import 'dart:math';
import 'dart:typed_data';

import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/restaurant_approval_model.dart';

/// Handles the restaurant approval queue workflow.
///
/// Covers:
/// - Fetching pending / reviewed approval items
/// - Admin accept (inserts Restaurant, optionally disables old one)
/// - Admin reject
/// - User-side submission of a new restaurant for review
class RestaurantApprovalRepository {
  RestaurantApprovalRepository._();
  static final RestaurantApprovalRepository instance =
      RestaurantApprovalRepository._();

  static const String _approvalImageBucket = 'restaurant_approval_image';

  /// Uploads a single image file for a restaurant approval to Supabase Storage.
  /// Path: approvals/<approvalId>/<imageId>.<ext>
  Future<String> uploadApprovalImageBytes({
    required String approvalId,
    required Uint8List bytes,
    String fileExt = 'jpg',
  }) async {
    final imageId = _generateUUID();
    final path = 'approvals/$approvalId/$imageId.$fileExt';

    await SupabaseService.client.storage
        .from(_approvalImageBucket)
        .uploadBinary(path, bytes);

    return SupabaseService.client.storage
        .from(_approvalImageBucket)
        .getPublicUrl(path);
  }

  // ---------------------------------------------------------------------------
  // 1. Fetch Approvals
  // ---------------------------------------------------------------------------

  /// Fetches pending (unreviewed) approval items, newest first.
  Future<List<RestaurantApprovalModel>> fetchPendingApprovals({
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await SupabaseService.client
        .from('RestaurantApproval')
        .select('''
          approval_Id,
          curr_restaurant_id,
          restaurant_name,
          address,
          latitude,
          longitude,
          maps_url,
          source,
          status,
          detectedAt,
          main_cuisine_id
        ''')
        .eq('status', 0)
        .order('detectedAt', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) =>
            RestaurantApprovalModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single approval item by its ID.
  /// Returns null if not found.
  Future<RestaurantApprovalModel?> fetchApprovalById(
      String approvalId) async {
    final response = await SupabaseService.client
        .from('RestaurantApproval')
        .select('''
          approval_Id,
          curr_restaurant_id,
          restaurant_name,
          address,
          latitude,
          longitude,
          maps_url,
          source,
          status,
          detectedAt,
          main_cuisine_id
        ''')
        .eq('approval_Id', approvalId)
        .maybeSingle();

    if (response == null) return null;
    return RestaurantApprovalModel.fromJson(response);
  }

  /// Fetches reviewed (accepted + rejected) approval items for history view.
  /// Pass [statusFilter] of 1 (accepted) or 2 (rejected) to narrow results,
  /// or omit to get all non-pending items.
  Future<List<RestaurantApprovalModel>> fetchApprovalHistory({
    int? statusFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = SupabaseService.client
        .from('RestaurantApproval')
        .select('''
          approval_Id,
          curr_restaurant_id,
          restaurant_name,
          address,
          latitude,
          longitude,
          maps_url,
          source,
          status,
          detectedAt,
          main_cuisine_id
        ''')
        .neq('status', 0);

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('detectedAt', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) =>
            RestaurantApprovalModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 2. Admin Actions
  // ---------------------------------------------------------------------------

  /// Accepts a pending approval item.
  ///
  /// Workflow:
  /// 1. Validate the approval exists and is still pending (status == 0).
  /// 2. Insert a new [Restaurant] row using the approval data.
  /// 3. If `curr_restaurant_id` is set, disable the old restaurant.
  /// 4. Mark the approval as accepted (status = 1).
  ///
  /// Returns the newly created restaurant ID.
  ///
  /// Note: Supabase Dart SDK does not support client-side transactions, so
  /// these are executed as sequential statements. If a later step fails the
  /// earlier writes will persist — but this is acceptable for an admin action
  /// where manual correction is feasible.
  ///
  /// TODO: After accepting, un-pend any Posts that were created for this
  /// restaurant while it was still in the approval queue. The exact linkage
  /// mechanism (how pending posts reference the approval) needs to be defined
  /// with the Post module owner.
  Future<String> acceptApproval(String approvalId) async {
    // 1. Fetch and validate
    final row = await SupabaseService.client
        .from('RestaurantApproval')
        .select()
        .eq('approval_Id', approvalId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Approval item not found.');
    }

    final approval = RestaurantApprovalModel.fromJson(row);

    if (approval.status != 0) {
      throw Exception('This approval has already been reviewed.');
    }

    // 2. Insert new Restaurant
    final newRestaurantId = _generateUUID();

    await SupabaseService.client.from('Restaurant').insert({
      'restaurant_Id': newRestaurantId,
      'restaurant_name': approval.name,
      'address': approval.address,
      'latitude': approval.latitude,
      'longitude': approval.longitude,
      'maps_url': approval.mapsUrl,
      'main_cuisine_id': approval.mainCuisineId,
      'source': approval.source ?? 'User',
      'isDisabled': false,
    });

    // 3. Disable old restaurant if this approval replaces an existing one
    final oldId = approval.currRestaurantId;
    if (oldId != null && oldId.isNotEmpty) {
      await SupabaseService.client
          .from('Restaurant')
          .update({'isDisabled': true})
          .eq('restaurant_Id', oldId);
    }

    // 4. Mark approval as accepted
    await SupabaseService.client
        .from('RestaurantApproval')
        .update({'status': 1})
        .eq('approval_Id', approvalId);

    return newRestaurantId;
  }

  /// Rejects a pending approval item (sets status = 2).
  Future<void> rejectApproval(String approvalId) async {
    final row = await SupabaseService.client
        .from('RestaurantApproval')
        .select('approval_Id, status')
        .eq('approval_Id', approvalId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Approval item not found.');
    }

    if ((row['status'] as int?) != 0) {
      throw Exception('This approval has already been reviewed.');
    }

    await SupabaseService.client
        .from('RestaurantApproval')
        .update({'status': 2})
        .eq('approval_Id', approvalId);
  }

  // ---------------------------------------------------------------------------
  // 3. User Submission
  // ---------------------------------------------------------------------------

  /// Submits a new restaurant for admin review.
  ///
  /// [currRestaurantId] should be provided when the user believes this replaces
  /// an existing restaurant at the same location (e.g. a shop that changed
  /// ownership). Leave null for a completely new restaurant.
  ///
  /// Returns the generated approval ID so the caller can reference it
  /// (e.g. to link a pending post).
  Future<String> submitForApproval({
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    String? mapsUrl,
    String? mainCuisineId,
    String? currRestaurantId,
    String source = 'User',
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Restaurant name is required.');
    }

    final approvalId = _generateUUID();

    await SupabaseService.client.from('RestaurantApproval').insert({
      'approval_Id': approvalId,
      'restaurant_name': name.trim(),
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'maps_url': mapsUrl,
      'main_cuisine_id': mainCuisineId,
      'curr_restaurant_id': currRestaurantId,
      'source': source,
      'status': 0,
    });

    return approvalId;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static final _secureRand = Random.secure();

  /// Client-side UUID v4 generation — matches the existing pattern used in
  /// PostRepository and CommentRepository.
  String _generateUUID() {
    final bytes = List<int>.generate(16, (_) => _secureRand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
        '-${hex.substring(20)}';
  }
}
