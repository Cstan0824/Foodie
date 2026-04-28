import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/collection_model.dart';
import '../models/restaurant_model.dart';
import 'notification_repository.dart';

class CollectionRepository {
  final SupabaseClient _supabase;
  late final NotificationRepository _notifRepo;

  CollectionRepository(this._supabase) {
    _notifRepo = NotificationRepository(_supabase);
  }

  // ==========================================
  // 1. Core Collection Management
  // ==========================================

  static const String _baseCollectionSelect = '''
    *,
    User!collections_user_Id_fkey(*, UserImage(image_url)),
    collections_item(
      savedAt,
      Post(post_Id, Post_Image(image_url)),
      Restaurant(restaurant_Id, Restaurant_Image(image_url, isCover))
    )
  ''';

  Future<List<Collection>> getUserCollections(String userId) async {
    final response = await _supabase
        .from('collections')
        .select(_baseCollectionSelect)
        .eq('user_Id', userId)
        .order('created_At', ascending: false);

    return _processCollectionResponse(response);
  }

  Future<List<Collection>> getSharedCollections(String userId) async {
    // 1. Get IDs of collections shared with this user
    final sharesResponse = await _supabase
        .from('collections_shares')
        .select('collection_Id')
        .eq('share_with_id', userId);

    final collectionIds = (sharesResponse as List<dynamic>)
        .map((row) => row['collection_Id'] as String)
        .toList();

    if (collectionIds.isEmpty) return [];

    // 2. Fetch those collections with owner (User) info
    final response = await _supabase
        .from('collections')
        .select(_baseCollectionSelect)
        .inFilter('collection_Id', collectionIds)
        .order('created_At', ascending: false);

    return _processCollectionResponse(response);
  }

  List<Collection> _processCollectionResponse(dynamic response) {
    final list = response as List<dynamic>;
    return list.map((json) {
      // Sort and limit items manually since PostgREST doesn't support
      // easy limiting of nested joins in this SDK version
      final items = json['collections_item'] as List<dynamic>?;
      if (items != null) {
        items.sort(
          (a, b) => (b['savedAt'] as String).compareTo(a['savedAt'] as String),
        );
        json['collections_item'] = items.take(2).toList();
      }
      return Collection.fromJson(json as Map<String, dynamic>);
    }).toList();
  }

  Future<Collection> cloneCollection({
    required String userId,
    required Collection sourceCollection,
  }) async {
    // 1. Create the new collection header
    final newCollectionId = const Uuid().v4();
    final response = await _supabase
        .from('collections')
        .insert({
          'collection_Id': newCollectionId,
          'user_Id': userId,
          'name': '${sourceCollection.name} (Copy)',
          'description': sourceCollection.description,
          'is_public': false, // Cloned collections are private by default
          'collection_type': sourceCollection.collectionType,
          'is_default': false,
        })
        .select()
        .single();

    // 2. Fetch all items from the source collection
    final itemsResponse = await _supabase
        .from('collections_item')
        .select('restaurant_id, post_id')
        .eq('collection_Id', sourceCollection.collectionId);

    final items = itemsResponse as List<dynamic>;

    if (items.isNotEmpty) {
      // 3. Insert them into the new collection
      final newItems = items
          .map(
            (item) => {
              'item_Id': const Uuid().v4(),
              'collection_Id': newCollectionId,
              'restaurant_id': item['restaurant_id'],
              'post_id': item['post_id'],
            },
          )
          .toList();

      await _supabase.from('collections_item').insert(newItems);
    }

    return Collection.fromJson(response);
  }

  Future<Collection> createCollection({
    required String userId,
    required String name,
    String? description,
    bool isPublic = false,
    String collectionType = 'POST',
  }) async {
    final response = await _supabase
        .from('collections')
        .insert({
          'collection_Id': const Uuid().v4(),
          'user_Id': userId,
          'name': name,
          'description': description,
          'is_public': isPublic,
          'collection_type': collectionType,
        })
        .select()
        .single();

    return Collection.fromJson(response);
  }

  Future<void> deleteCollection(String collectionId) async {
    // The foreign keys in schema handle cascade deletes for shares & posts
    await _supabase
        .from('collections')
        .delete()
        .eq('collection_Id', collectionId);
  }

  Future<void> updateCollectionInfo(
    String collectionId, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (isPublic != null) updates['is_public'] = isPublic;

    if (updates.isNotEmpty) {
      await _supabase
          .from('collections')
          .update(updates)
          .eq('collection_Id', collectionId);
    }
  }

  // ==========================================
  // 2. Collection Posts Management
  // ==========================================

  Future<void> savePostToCollection(String collectionId, String postId) async {
    await _supabase.from('collections_item').insert({
      'collection_Id': collectionId,
      'post_id': postId,
    });
  }

  Future<void> removePostFromCollection(
    String collectionId,
    String postId,
  ) async {
    await _supabase
        .from('collections_item')
        .delete()
        .eq('collection_Id', collectionId)
        .eq('post_id', postId);
  }

  Future<List<String>> getSavedPostIdsForUser(String userId) async {
    final collectionsResponse = await _supabase
        .from('collections')
        .select('collection_Id')
        .eq('user_Id', userId);

    final collectionIds = (collectionsResponse as List<dynamic>)
        .map((row) => row['collection_Id'] as String?)
        .whereType<String>()
        .toList();

    if (collectionIds.isEmpty) return [];

    final itemsResponse = await _supabase
        .from('collections_item')
        .select('post_id')
        .inFilter('collection_Id', collectionIds)
        .order('savedAt', ascending: false);

    final savedPostIds = <String>{};
    for (final row in (itemsResponse as List<dynamic>)) {
      final postId = row['post_id'] as String?;
      if (postId != null && postId.isNotEmpty) {
        savedPostIds.add(postId);
      }
    }

    return savedPostIds.toList();
  }

  // ==========================================
  // 3. Collection Sharing Management
  // ==========================================

  Future<List<String>> getSharedUserIds(String collectionId) async {
    final response = await _supabase
        .from('collections_shares')
        .select('share_with_id')
        .eq('collection_Id', collectionId);

    return (response as List<dynamic>)
        .map((row) => row['share_with_id'] as String)
        .toList();
  }

  Future<Collection?> getDefaultPostCollection(String userId) async {
    final response = await _supabase
        .from('collections')
        .select()
        .eq('user_Id', userId)
        .eq('is_default', true)
        .eq('collection_type', 'POST')
        .maybeSingle();

    if (response == null) return null;
    return Collection.fromJson(response);
  }

  Future<void> shareCollection(String collectionId, String targetUserId) async {
    await _supabase.from('collections_shares').insert({
      'collection_Id': collectionId,
      'share_with_id': targetUserId,
    });

    // Automatically make collection public when shared with someone
    await _supabase
        .from('collections')
        .update({'is_public': true})
        .eq('collection_Id', collectionId);

    // Trigger notification
    _triggerShareNotification(collectionId, targetUserId);
  }

  Future<void> _triggerShareNotification(
    String collectionId,
    String targetUserId,
  ) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final collData = await _supabase
          .from('collections')
          .select('name')
          .eq('collection_Id', collectionId)
          .maybeSingle();

      final collectionName = collData?['name'] as String?;
      if (collectionName != null) {
        await _notifRepo.notifyCollectionShare(
          sharerId: currentUserId,
          targetUserId: targetUserId,
          collectionId: collectionId,
          collectionName: collectionName,
        );
      }
    } catch (_) {}
  }

  Future<void> removeShare(String collectionId, String targetUserId) async {
    await _supabase
        .from('collections_shares')
        .delete()
        .eq('collection_Id', collectionId)
        .eq('share_with_id', targetUserId);
  }

  /// Returns the real total number of times [postId] has been saved,
  /// counted directly from [collections_item] rows (not the cached Post.saveCount column).
  Future<int> getPostSaveCount(String postId) async {
    final response = await _supabase
        .from('collections_item')
        .select('item_Id')
        .eq('post_id', postId);
    return (response as List<dynamic>).length;
  }

  /// Returns true if [userId] has already saved [postId] in any of their collections.
  Future<bool> isPostSavedByUser({
    required String userId,
    required String postId,
  }) async {
    final collectionIds = await _supabase
        .from('collections')
        .select('collection_Id')
        .eq('user_Id', userId);

    final ids = (collectionIds as List<dynamic>)
        .map((r) => r['collection_Id'] as String?)
        .whereType<String>()
        .toList();

    if (ids.isEmpty) return false;

    final saved = await _supabase
        .from('collections_item')
        .select('item_Id')
        .eq('post_id', postId)
        .inFilter('collection_Id', ids)
        .limit(1);

    return (saved as List<dynamic>).isNotEmpty;
  }

  /// Removes [postId] from every collection owned by [userId].
  Future<void> unsavePostForUser({
    required String userId,
    required String postId,
  }) async {
    final collectionIds = await _supabase
        .from('collections')
        .select('collection_Id')
        .eq('user_Id', userId);

    final ids = (collectionIds as List<dynamic>)
        .map((r) => r['collection_Id'] as String?)
        .whereType<String>()
        .toList();

    if (ids.isEmpty) return;

    await _supabase
        .from('collections_item')
        .delete()
        .eq('post_id', postId)
        .inFilter('collection_Id', ids);
  }

  // ==========================================
  // 4. Collection Restaurants Management
  // ==========================================

  Future<List<RestaurantModel>> getRestaurantsInCollection(
    String collectionId,
  ) async {
    final itemsResponse = await _supabase
        .from('collections_item')
        .select('restaurant_id')
        .eq('collection_Id', collectionId);

    final restaurantIds = (itemsResponse as List<dynamic>)
        .map((row) => row['restaurant_id'] as String?)
        .whereType<String>()
        .toList();

    if (restaurantIds.isEmpty) return [];

    final response = await _supabase
        .from('Restaurant')
        .select(
          'restaurant_Id, restaurant_name, description, price_range, address, latitude, longitude, maps_url, created_At, main_cuisine_id, source, info_url, isDisabled, rating, mainCuisine:Cuisine!restaurant_main_cuisine_fk(type_id, desc, isPrimaryOption), Restaurant_Image(image_id, image_url, isCover)',
        )
        .inFilter('restaurant_Id', restaurantIds)
        .eq('isDisabled', false);

    return (response as List<dynamic>)
        .map((row) => RestaurantModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeRestaurantFromCollection(
    String collectionId,
    String restaurantId,
  ) async {
    await _supabase
        .from('collections_item')
        .delete()
        .eq('collection_Id', collectionId)
        .eq('restaurant_id', restaurantId);
  }

  Future<void> removeRestaurantsFromCollection(
    String collectionId,
    List<String> restaurantIds,
  ) async {
    if (restaurantIds.isEmpty) return;
    await _supabase
        .from('collections_item')
        .delete()
        .eq('collection_Id', collectionId)
        .inFilter('restaurant_id', restaurantIds);
  }
}
