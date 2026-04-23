import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/collection_model.dart';

class CollectionRepository {
  final SupabaseClient _supabase;

  CollectionRepository(this._supabase);

  // ==========================================
  // 1. Core Collection Management
  // ==========================================

  Future<List<Collection>> getUserCollections(String userId) async {
    final response = await _supabase
        .from('collections')
        .select()
        .eq('user_Id', userId)
        .order('created_At', ascending: false);

    return (response as List).map((json) => Collection.fromJson(json)).toList();
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
}
