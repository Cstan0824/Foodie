import 'dart:math';
import 'dart:typed_data';

import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/restaurant_approval_model.dart';
import 'package:taste_spot/data/repositories/restaurant_repository.dart';

class ApprovalFinalImageInput {
  final String? existingUrl;
  final Uint8List? bytes;
  final String fileExt;
  final bool isCover;

  const ApprovalFinalImageInput.existing({
    required String url,
    this.isCover = false,
  }) : existingUrl = url,
       bytes = null,
       fileExt = 'jpg';

  const ApprovalFinalImageInput.upload({
    required this.bytes,
    this.fileExt = 'jpg',
    this.isCover = false,
  }) : existingUrl = null;
}

class ApprovalDecisionInput {
  final String approvalId;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? mapsUrl;
  final String? infoUrl;
  final String source;
  final String? mainCuisineId;
  final double? rating;
  final List<String> extraCuisineIds;
  final List<ApprovalFinalImageInput> images;

  const ApprovalDecisionInput({
    required this.approvalId,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.mapsUrl,
    this.infoUrl,
    required this.source,
    this.mainCuisineId,
    this.rating,
    this.extraCuisineIds = const [],
    this.images = const [],
  });
}

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
  static const String _approvalSelect = '''
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
          main_cuisine_id,
          rating,
          image_url
        ''';

  final RestaurantRepository _restaurantRepo = RestaurantRepository.instance;

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
        .map(
          (row) =>
              RestaurantApprovalModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  /// Fetches approvals with optional status + search filters.
  ///
  /// [statusFilter]:
  /// - null => all statuses
  /// - 0 => pending only
  /// - 1 => accepted only
  /// - 2 => rejected only
  Future<List<RestaurantApprovalModel>> fetchApprovals({
    int? statusFilter,
    String? searchQuery,
    int limit = 30,
    int offset = 0,
  }) async {
    var query = SupabaseService.client
        .from('RestaurantApproval')
        .select(_approvalSelect);

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      query = query.or('restaurant_name.ilike.%$q%,address.ilike.%$q%');
    }

    final response = await query
        .order('detectedAt', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map(
          (row) =>
              RestaurantApprovalModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  /// Fetches a single approval item by its ID.
  /// Returns null if not found.
  Future<RestaurantApprovalModel?> fetchApprovalById(String approvalId) async {
    final response = await SupabaseService.client
        .from('RestaurantApproval')
        .select(_approvalSelect)
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
        .select(_approvalSelect)
        .neq('status', 0);

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('detectedAt', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map(
          (row) =>
              RestaurantApprovalModel.fromJson(row as Map<String, dynamic>),
        )
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

  /// Accepts one approval using reviewed values from the approval-review form.
  ///
  /// This method enforces the admin flow:
  /// 1) Persist reviewed values into RestaurantApproval
  /// 2) Create Restaurant from reviewed values
  /// 3) Persist extra cuisines + final images
  /// 4) Disable old restaurant when applicable
  /// 5) Un-pend linked posts and point them to the new Restaurant
  /// 6) Mark approval status as accepted
  Future<String> acceptApprovalReviewed(ApprovalDecisionInput input) async {
    final row = await SupabaseService.client
        .from('RestaurantApproval')
        .select('approval_Id, status, curr_restaurant_id')
        .eq('approval_Id', input.approvalId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Approval item not found.');
    }

    if ((row['status'] as int?) != 0) {
      throw Exception('This approval has already been reviewed.');
    }

    await _persistReviewedApprovalValues(input);

    final restaurantId = await _restaurantRepo.saveRestaurant(
      name: input.name,
      address: input.address,
      mainCuisineId: input.mainCuisineId ?? '',
      latitude: input.latitude,
      longitude: input.longitude,
      mapsUrl: input.mapsUrl,
      infoUrl: input.infoUrl,
      source: input.source,
      rating: input.rating,
      extraCuisineIds: input.extraCuisineIds,
      images: const [],
    );

    final finalImageRows = await _materializeFinalRestaurantImages(
      restaurantId: restaurantId,
      images: input.images,
    );

    if (finalImageRows.isNotEmpty) {
      await _restaurantRepo.replaceRestaurantImages(
        restaurantId,
        finalImageRows,
      );
    }

    final oldRestaurantId = row['curr_restaurant_id']?.toString();
    if (oldRestaurantId != null && oldRestaurantId.isNotEmpty) {
      await _restaurantRepo.setDisabled(oldRestaurantId, true);
    }

    await SupabaseService.client
        .from('Post')
        .update({
          'restaurant_Id': restaurantId,
          'isPending': false,
          'restaurant_approval_id': null,
        })
        .eq('restaurant_approval_id', input.approvalId)
        .eq('isPending', true);

    await SupabaseService.client
        .from('RestaurantApproval')
        .update({'status': 1})
        .eq('approval_Id', input.approvalId);

    return restaurantId;
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

  /// Rejects one approval using reviewed values from the approval-review form.
  ///
  /// This method enforces the admin flow:
  /// 1) Persist reviewed values into RestaurantApproval
  /// 2) Block linked pending posts (keep restaurant_approval_id)
  /// 3) Mark approval status as rejected
  Future<void> rejectApprovalReviewed(ApprovalDecisionInput input) async {
    final row = await SupabaseService.client
        .from('RestaurantApproval')
        .select('approval_Id, status')
        .eq('approval_Id', input.approvalId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Approval item not found.');
    }

    if ((row['status'] as int?) != 0) {
      throw Exception('This approval has already been reviewed.');
    }

    await _persistReviewedApprovalValues(input);

    await SupabaseService.client
        .from('Post')
        .update({'isBlocked': true, 'isPending': false})
        .eq('restaurant_approval_id', input.approvalId)
        .eq('isPending', true);

    await SupabaseService.client
        .from('RestaurantApproval')
        .update({'status': 2})
        .eq('approval_Id', input.approvalId);
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

  Future<void> _persistReviewedApprovalValues(ApprovalDecisionInput input) {
    return SupabaseService.client
        .from('RestaurantApproval')
        .update({
          'restaurant_name': input.name.trim(),
          'address': input.address.trim(),
          'latitude': input.latitude,
          'longitude': input.longitude,
          'maps_url': input.mapsUrl,
          'source': input.source.trim().isEmpty ? 'User' : input.source.trim(),
          'rating': input.rating,
          if (input.mainCuisineId != null &&
              input.mainCuisineId!.trim().isNotEmpty)
            'main_cuisine_id': input.mainCuisineId,
          if (input.infoUrl != null) 'info_url': input.infoUrl,
        })
        .eq('approval_Id', input.approvalId);
  }

  Future<List<RestaurantImageRecord>> _materializeFinalRestaurantImages({
    required String restaurantId,
    required List<ApprovalFinalImageInput> images,
  }) async {
    if (images.isEmpty) return const [];

    final rows = <RestaurantImageRecord>[];

    for (final item in images) {
      if (item.bytes != null) {
        final uploaded = await _restaurantRepo.uploadRestaurantImageBytes(
          restaurantId: restaurantId,
          bytes: item.bytes!,
          fileExt: item.fileExt,
          isCover: item.isCover,
        );
        rows.add(uploaded);
        continue;
      }

      final existingUrl = item.existingUrl;
      if (existingUrl != null && existingUrl.trim().isNotEmpty) {
        rows.add(
          RestaurantImageRecord(
            imageId: _generateUUID(),
            imageUrl: existingUrl,
            isCover: item.isCover,
          ),
        );
      }
    }

    if (rows.isEmpty) return const [];

    final hasCover = rows.any((img) => img.isCover);
    if (!hasCover) {
      rows[0] = rows[0].copyWith(isCover: true);
    }

    return rows;
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
