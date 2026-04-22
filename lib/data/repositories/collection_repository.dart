import 'package:supabase_flutter/supabase_flutter.dart';
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
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Collection.fromJson(json)).toList();
  }

  Future<Collection> createCollection({
    required String userId,
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    final response = await _supabase.from('collections').insert({
      'user_id': userId,
      'name': name,
      'description': description,
      'is_public': isPublic,
    }).select().single();

    return Collection.fromJson(response);
  }

  Future<void> deleteCollection(String collectionId) async {
    // The foreign keys in schema handle cascade deletes for shares & posts
    await _supabase.from('collections').delete().eq('collection_id', collectionId);
  }

  Future<void> updateCollectionInfo(String collectionId, {String? name, String? description, bool? isPublic}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (isPublic != null) updates['is_public'] = isPublic;

    if (updates.isNotEmpty) {
      await _supabase.from('collections').update(updates).eq('collection_id', collectionId);
    }
  }

  // ==========================================
  // 2. Collection Posts Management
  // ==========================================

  Future<void> savePostToCollection(String collectionId, String postId) async {
    await _supabase.from('collections_post').insert({
      'collection_id': collectionId,
      'post_id': postId,
    });
  }

  Future<void> removePostFromCollection(String collectionId, String postId) async {
    await _supabase
        .from('collections_post')
        .delete()
        .eq('collection_id', collectionId)
        .eq('post_id', postId);
  }

  // ==========================================
  // 3. Collection Sharing Management
  // ==========================================

  Future<void> shareCollection(String collectionId, String targetUserId) async {
    await _supabase.from('collections_shares').insert({
      'collection_id': collectionId,
      'share_with_id': targetUserId,
    });
  }

  Future<void> removeShare(String collectionId, String targetUserId) async {
    await _supabase
        .from('collections_shares')
        .delete()
        .eq('collection_id', collectionId)
        .eq('share_with_id', targetUserId);
  }
}
