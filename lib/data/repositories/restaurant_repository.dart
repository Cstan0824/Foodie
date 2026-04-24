import 'dart:math';
import 'dart:typed_data';

import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/data/models/cuisine_model.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';

class RestaurantImageRecord {
  final String imageId;
  final String imageUrl;
  final bool isCover;

  const RestaurantImageRecord({
    required this.imageId,
    required this.imageUrl,
    required this.isCover,
  });

  factory RestaurantImageRecord.fromJson(Map<String, dynamic> json) {
    return RestaurantImageRecord(
      imageId: json['image_id'] as String,
      imageUrl: json['image_url'] as String,
      isCover: json['isCover'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toInsertJson(String restaurantId) {
    return {
      'image_id': imageId,
      'restaurant_id': restaurantId,
      'image_url': imageUrl,
      'isCover': isCover,
    };
  }

  RestaurantImageRecord copyWith({
    String? imageId,
    String? imageUrl,
    bool? isCover,
  }) {
    return RestaurantImageRecord(
      imageId: imageId ?? this.imageId,
      imageUrl: imageUrl ?? this.imageUrl,
      isCover: isCover ?? this.isCover,
    );
  }
}


class RestaurantDetailData {
  final RestaurantModel restaurant;
  final List<CuisineModel> extraCuisines;
  final List<RestaurantImageRecord> images;

  const RestaurantDetailData({
    required this.restaurant,
    required this.extraCuisines,
    required this.images,
  });

  String? get coverImageUrl {
    if (images.isEmpty) return null;
    for (final image in images) {
      if (image.isCover) return image.imageUrl;
    }
    return images.first.imageUrl;
  }
}

class RestaurantBasicInfo {
  final String restaurantId;
  final String name;
  final String? address;
  final String? mainCuisineName;
  final bool isDisabled;
  final String? source;
  final String? coverImageUrl;

  const RestaurantBasicInfo({
    required this.restaurantId,
    required this.name,
    required this.address,
    required this.mainCuisineName,
    required this.isDisabled,
    required this.source,
    required this.coverImageUrl,
  });
}

class RestaurantRepository {
  RestaurantRepository._();
  static final RestaurantRepository instance = RestaurantRepository._();

  static const String _imageTable = 'Restaurant_Image';
  static const String _restaurantImageBucket = 'restaurant_images';

  /// Full select with cuisine join — used by admin views that need all columns.
  static const String _fullSelect = '''
    restaurant_Id,
    restaurant_name,
    description,
    price_range,
    address,
    latitude,
    longitude,
    maps_url,
    created_At,
    main_cuisine_id,
    source,
    info_url,
    isDisabled,
    rating,
    mainCuisine:Cuisine!restaurant_main_cuisine_fk(type_id, desc, isPrimaryOption),
    Restaurant_Image(image_id, image_url, isCover)
  ''';

  // ===========================================================================
  // User-facing queries (existing)
  // ===========================================================================

  /// Searches restaurants by name (case-insensitive prefix match).
  Future<List<RestaurantModel>> searchRestaurants(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    final response = await SupabaseService.client
        .from('Restaurant')
        .select(
          'restaurant_Id, restaurant_name, description, price_range, address, latitude, longitude, maps_url, created_At, main_cuisine_id, source, info_url, isDisabled, rating, mainCuisine:Cuisine!restaurant_main_cuisine_fk(type_id, desc, isPrimaryOption), Restaurant_Image(image_id, image_url, isCover)',
        )
        .eq('isDisabled', false)
        .ilike('restaurant_name', '%$query%')
        .order('restaurant_name')
        .limit(limit);

    return (response as List<dynamic>)
        .map((row) => RestaurantModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches all restaurants (for showing a default list before search).
  Future<List<RestaurantModel>> fetchRecent({int limit = 10}) async {
    final response = await SupabaseService.client
        .from('Restaurant')
        .select(
          'restaurant_Id, restaurant_name, description, price_range, address, latitude, longitude, maps_url, created_At, main_cuisine_id, source, info_url, isDisabled, rating, mainCuisine:Cuisine!restaurant_main_cuisine_fk(type_id, desc, isPrimaryOption), Restaurant_Image(image_id, image_url, isCover)',
        )
        .eq('isDisabled', false)
        .order('created_At', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((row) => RestaurantModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ===========================================================================
  // Admin — Restaurant CRUD
  // ===========================================================================

  /// Fetches all restaurants for admin (includes disabled ones).
  /// Supports optional search filter and disabled-state filter.
  Future<List<RestaurantModel>> fetchAllRestaurants({
    String? searchQuery,
    bool? isDisabled,
    String? source,
    List<String>? cuisineIds,
    int limit = 30,
    int offset = 0,
  }) async {
    var query = SupabaseService.client.from('Restaurant').select(_fullSelect);

    if (isDisabled != null) {
      query = query.eq('isDisabled', isDisabled);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      query = query.or('restaurant_name.ilike.%$q%,address.ilike.%$q%');
    }

    if (source != null && source.trim().isNotEmpty && source != 'all') {
      query = query.ilike('source', source.trim());
    }

    if (cuisineIds != null && cuisineIds.isNotEmpty) {
      // First, find all restaurants that have these cuisines as extra tags
      final tagRows = await SupabaseService.client
          .from('Restaurant_Cuisine')
          .select('RestaurantId')
          .inFilter('CuisineId', cuisineIds);

      final extraRestaurantIds = (tagRows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['RestaurantId']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final mainCuisineFilter = 'main_cuisine_id.in.(${cuisineIds.join(',')})';
      
      if (extraRestaurantIds.isNotEmpty) {
        final extraFilter = 'restaurant_Id.in.(${extraRestaurantIds.join(',')})';
        query = query.or('$mainCuisineFilter,$extraFilter');
      } else {
        query = query.or(mainCuisineFilter);
      }
    }

    final response = await query
        .order('created_At', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) => RestaurantModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single restaurant by ID (includes disabled restaurants).
  Future<RestaurantModel?> fetchRestaurantById(String restaurantId) async {
    final response = await SupabaseService.client
        .from('Restaurant')
        .select(_fullSelect)
        .eq('restaurant_Id', restaurantId)
        .maybeSingle();

    if (response == null) return null;
    return RestaurantModel.fromJson(response);
  }

  /// Fetches a lightweight preview payload for one restaurant.
  /// Useful for approval review headers and side-by-side comparisons.
  Future<RestaurantBasicInfo?> fetchRestaurantBasicInfo(
    String restaurantId,
  ) async {
    final response = await SupabaseService.client
        .from('Restaurant')
        .select('''
          restaurant_Id,
          restaurant_name,
          description,
          price_range,
          latitude,
          longitude,
          maps_url,
          address,
          source,
          info_url,
          rating,
          main_cuisine_id,
          isDisabled,
          mainCuisine:Cuisine!restaurant_main_cuisine_fk(type_id, desc, isPrimaryOption),
          Restaurant_Image(image_id, image_url, isCover)
        ''')
        .eq('restaurant_Id', restaurantId)
        .maybeSingle();

    if (response == null) return null;

    final row = response;
    final images = (row['Restaurant_Image'] as List<dynamic>? ?? const [])
        .map((img) => img as Map<String, dynamic>)
        .toList();

    String? coverImageUrl;
    if (images.isNotEmpty) {
      final cover = images.firstWhere(
        (img) => (img['isCover'] as bool?) ?? false,
        orElse: () => images.first,
      );
      coverImageUrl = cover['image_url']?.toString();
    }

    return RestaurantBasicInfo(
      restaurantId: row['restaurant_Id']?.toString() ?? '',
      name: row['restaurant_name']?.toString() ?? '',
      address: row['address']?.toString(),
      mainCuisineName:
          (row['mainCuisine'] as Map<String, dynamic>?)?['desc']?.toString(),
      isDisabled: row['isDisabled'] as bool? ?? false,
      source: row['source']?.toString(),
      coverImageUrl: coverImageUrl,
    );
  }

  /// Fetches a full detail payload for View Restaurant Screen.
  /// Includes restaurant row, all image metadata, and extra cuisine tags.
  Future<RestaurantDetailData?> fetchRestaurantDetail(
    String restaurantId,
  ) async {
    final restaurant = await fetchRestaurantById(restaurantId);
    if (restaurant == null) return null;

    final images = await fetchRestaurantImages(restaurantId);
    final extraCuisines = await fetchRestaurantCuisineTags(restaurantId);

    return RestaurantDetailData(
      restaurant: restaurant,
      extraCuisines: extraCuisines,
      images: images,
    );
  }

  /// Creates a new restaurant directly (admin bypass — no approval queue).
  /// Returns the generated restaurant ID.
  Future<String> createRestaurant({
    required String name,
    String? description,
    String? priceRange,
    String? address,
    double? latitude,
    double? longitude,
    String? mapsUrl,
    String? mainCuisineId,
    String? infoUrl,
    String source = 'ADMIN',
    double? rating,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Restaurant name is required.');
    }

    final restaurantId = _generateUUID();

    await SupabaseService.client.from('Restaurant').insert({
      'restaurant_Id': restaurantId,
      'restaurant_name': name.trim(),
      'description': description,
      'price_range': priceRange,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'maps_url': mapsUrl,
      'main_cuisine_id': mainCuisineId,
      'info_url': infoUrl,
      'source': source,
      'rating': rating,
      'isDisabled': false,
    });

    return restaurantId;
  }

  /// Updates an existing restaurant's details.
  /// Only the provided (non-null) fields are written.
  Future<void> updateRestaurant({
    required String restaurantId,
    String? name,
    String? description,
    String? priceRange,
    String? address,
    double? latitude,
    double? longitude,
    String? mapsUrl,
    String? mainCuisineId,
    String? infoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['restaurant_name'] = name.trim();
    if (description != null) updates['description'] = description;
    if (priceRange != null) updates['price_range'] = priceRange;
    if (address != null) updates['address'] = address;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;
    if (mapsUrl != null) updates['maps_url'] = mapsUrl;
    if (mainCuisineId != null) updates['main_cuisine_id'] = mainCuisineId;
    if (infoUrl != null) updates['info_url'] = infoUrl;

    if (updates.isEmpty) return;

    final response = await SupabaseService.client
        .from('Restaurant')
        .update(updates)
        .eq('restaurant_Id', restaurantId)
        .select('restaurant_Id')
        .maybeSingle();

    if (response == null) {
      throw Exception('Restaurant not found.');
    }
  }

  /// Overwrites editable restaurant fields (add/edit form friendly).
  /// Unlike [updateRestaurant], null values here will clear DB columns.
  Future<void> updateRestaurantDetails({
    required String restaurantId,
    required String name,
    String? description,
    String? priceRange,
    required String address,
    required String mainCuisineId,
    double? latitude,
    double? longitude,
    String? mapsUrl,
    String? infoUrl,
    String? source,
    double? rating,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Restaurant name is required.');
    }
    if (address.trim().isEmpty) {
      throw Exception('Restaurant address is required.');
    }
    if (mainCuisineId.trim().isEmpty) {
      throw Exception('Main cuisine is required.');
    }

    final response = await SupabaseService.client
        .from('Restaurant')
        .update({
          'restaurant_name': name.trim(),
          'description': description,
          'price_range': priceRange,
          'address': address.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'maps_url': mapsUrl,
          'main_cuisine_id': mainCuisineId,
          'info_url': infoUrl,
          if (source != null) 'source': source,
          'rating': rating,
        })
        .eq('restaurant_Id', restaurantId)
        .select('restaurant_Id')
        .maybeSingle();

    if (response == null) {
      throw Exception('Restaurant not found.');
    }
  }

  /// Enables or disables a restaurant.
  Future<void> setDisabled(String restaurantId, bool disabled) async {
    final response = await SupabaseService.client
        .from('Restaurant')
        .update({'isDisabled': disabled})
        .eq('restaurant_Id', restaurantId)
        .select('restaurant_Id')
        .maybeSingle();

    if (response == null) {
      throw Exception('Restaurant not found.');
    }
  }

  /// Convenience helper for View Restaurant Screen action buttons.
  Future<void> setRestaurantEnabled(String restaurantId, bool enabled) {
    return setDisabled(restaurantId, !enabled);
  }

  // ===========================================================================
  // Admin — Cuisine Lookup
  // ===========================================================================

  /// Creates a new cuisine type and returns its generated UUID.
  Future<String> createCuisine({
    required String name,
    bool isPrimaryOption = false,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Cuisine name is required.');
    }

    final cuisineId = _generateUUID();

    await SupabaseService.client.from('Cuisine').insert({
      'type_id': cuisineId,
      'desc': name.trim(),
      'isPrimaryOption': isPrimaryOption,
    });

    return cuisineId;
  }

  /// Fetches all cuisine types (for admin tag assignment dropdowns).
  Future<List<CuisineModel>> fetchAllCuisines() async {
    final response = await SupabaseService.client
        .from('Cuisine')
        .select('type_id, desc, isPrimaryOption')
        .order('desc');

    return (response as List<dynamic>)
        .map((row) => CuisineModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches only cuisines marked as primary options
  /// (for user-facing restaurant submission forms).
  Future<List<CuisineModel>> fetchPrimaryCuisines() async {
    final response = await SupabaseService.client
        .from('Cuisine')
        .select('type_id, desc, isPrimaryOption')
        .eq('isPrimaryOption', true)
        .order('desc');

    return (response as List<dynamic>)
        .map((row) => CuisineModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ===========================================================================
  // Admin — Cuisine Tag Management (Restaurant_Cuisine)
  // ===========================================================================

  /// Fetches the extra cuisine tags currently assigned to a restaurant.
  /// These are from the [Restaurant_Cuisine] junction table, NOT the main
  /// cuisine (which lives on Restaurant.main_cuisine_id).
  Future<List<CuisineModel>> fetchRestaurantCuisineTags(
    String restaurantId,
  ) async {
    // Step 1: get tag IDs from junction table
    final tagRows = await SupabaseService.client
        .from('Restaurant_Cuisine')
        .select('CuisineId')
        .eq('RestaurantId', restaurantId);

    final cuisineIds = (tagRows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['CuisineId']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (cuisineIds.isEmpty) return [];

    // Step 2: fetch full cuisine details
    final cuisineRows = await SupabaseService.client
        .from('Cuisine')
        .select('type_id, desc, isPrimaryOption')
        .inFilter('type_id', cuisineIds)
        .order('desc');

    return (cuisineRows as List<dynamic>)
        .map((row) => CuisineModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Replaces all extra cuisine tags for a restaurant.
  /// Strategy: delete existing tags, then insert the new set.
  /// Pass an empty list to remove all tags.
  Future<void> updateCuisineTags(
    String restaurantId,
    List<String> cuisineIds,
  ) async {
    // 1. Remove all existing tags
    await SupabaseService.client
        .from('Restaurant_Cuisine')
        .delete()
        .eq('RestaurantId', restaurantId);

    // 2. Insert new tags (if any)
    if (cuisineIds.isNotEmpty) {
      final rows = cuisineIds
          .map((cId) => {'RestaurantId': restaurantId, 'CuisineId': cId})
          .toList();

      await SupabaseService.client.from('Restaurant_Cuisine').insert(rows);
    }
  }

  // ===========================================================================
  // Admin — Restaurant Images (restaurant_image)
  // ===========================================================================

  /// Fetches all image rows for a restaurant.
  Future<List<RestaurantImageRecord>> fetchRestaurantImages(
    String restaurantId,
  ) async {
    final response = await SupabaseService.client
        .from(_imageTable)
        .select('image_id, image_url, isCover')
        .eq('restaurant_id', restaurantId)
        .order('isCover', ascending: false)
        .order('image_id', ascending: true);

    return (response as List<dynamic>)
        .map(
          (row) => RestaurantImageRecord.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  /// Replaces all image rows for a restaurant and enforces exactly one cover
  /// whenever the list is non-empty.
  Future<void> replaceRestaurantImages(
    String restaurantId,
    List<RestaurantImageRecord> images,
  ) async {
    await SupabaseService.client
        .from(_imageTable)
        .delete()
        .eq('restaurant_id', restaurantId);

    if (images.isEmpty) return;

    final normalized = List<RestaurantImageRecord>.from(images);
    final hasCover = normalized.any((img) => img.isCover);
    if (!hasCover) {
      normalized[0] = normalized[0].copyWith(isCover: true);
    } else {
      var seenCover = false;
      for (var i = 0; i < normalized.length; i++) {
        if (normalized[i].isCover) {
          if (!seenCover) {
            seenCover = true;
          } else {
            normalized[i] = normalized[i].copyWith(isCover: false);
          }
        }
      }
    }

    final rows = normalized
        .map((img) => img.toInsertJson(restaurantId))
        .toList();

    await SupabaseService.client.from(_imageTable).insert(rows);
  }

  /// Marks one image as cover and unsets all others for the same restaurant.
  Future<void> setRestaurantCoverImage({
    required String restaurantId,
    required String imageId,
  }) async {
    await SupabaseService.client
        .from(_imageTable)
        .update({'isCover': false})
        .eq('restaurant_id', restaurantId);

    final updated = await SupabaseService.client
        .from(_imageTable)
        .update({'isCover': true})
        .eq('restaurant_id', restaurantId)
        .eq('image_id', imageId)
        .select('image_id')
        .maybeSingle();

    if (updated == null) {
      throw Exception('Restaurant image not found.');
    }
  }

  /// Removes one image row and optionally cleans up its storage blob.
  Future<void> removeRestaurantImage({
    required String restaurantId,
    required String imageId,
    bool removeFromStorage = true,
  }) async {
    final image = await SupabaseService.client
        .from(_imageTable)
        .select('image_url, isCover')
        .eq('restaurant_id', restaurantId)
        .eq('image_id', imageId)
        .maybeSingle();

    if (image == null) {
      throw Exception('Restaurant image not found.');
    }

    await SupabaseService.client
        .from(_imageTable)
        .delete()
        .eq('restaurant_id', restaurantId)
        .eq('image_id', imageId);

    if (removeFromStorage) {
      final path = _extractStoragePath(
        (image['image_url'] as String?) ?? '',
        _restaurantImageBucket,
      );

      if (path != null) {
        try {
          await SupabaseService.client.storage
              .from(_restaurantImageBucket)
              .remove([path]);
        } catch (_) {}
      }
    }

    final remaining = await fetchRestaurantImages(restaurantId);
    if (remaining.isNotEmpty && !remaining.any((img) => img.isCover)) {
      await setRestaurantCoverImage(
        restaurantId: restaurantId,
        imageId: remaining.first.imageId,
      );
    }
  }

  /// Uploads one image file to Supabase Storage and returns public URL.
  Future<RestaurantImageRecord> uploadRestaurantImageBytes({
    required String restaurantId,
    required Uint8List bytes,
    String fileExt = 'jpg',
    bool isCover = false,
  }) async {
    final imageId = _generateUUID();
    final path = 'restaurants/$restaurantId/$imageId.$fileExt';

    await SupabaseService.client.storage
        .from(_restaurantImageBucket)
        .uploadBinary(path, bytes);

    final publicUrl = SupabaseService.client.storage
        .from(_restaurantImageBucket)
        .getPublicUrl(path);

    return RestaurantImageRecord(
      imageId: imageId,
      imageUrl: publicUrl,
      isCover: isCover,
    );
  }

  /// Single save entry-point for add/edit form wiring.
  /// Handles base restaurant row, extra cuisine tags, and image metadata rows.
  Future<String> saveRestaurant({
    String? restaurantId,
    required String name,
    String? description,
    String? priceRange,
    required String address,
    required String mainCuisineId,
    double? latitude,
    double? longitude,
    String? mapsUrl,
    String? infoUrl,
    String source = 'ADMIN',
    double? rating,
    List<String> extraCuisineIds = const [],
    List<RestaurantImageRecord> images = const [],
  }) async {
    final normalizedSource = source.trim().isEmpty ? 'ADMIN' : source.trim().toUpperCase();

    final id = restaurantId ?? await createRestaurant(
            name: name,
            description: description,
            priceRange: priceRange,
            address: address,
            latitude: latitude,
            longitude: longitude,
            mapsUrl: mapsUrl,
            mainCuisineId: mainCuisineId,
            infoUrl: infoUrl,
            source: normalizedSource,
            rating: rating,
          );

    if (restaurantId != null) {
      await updateRestaurantDetails(
        restaurantId: id,
        name: name,
        description: description,
        priceRange: priceRange,
        address: address,
        mainCuisineId: mainCuisineId,
        latitude: latitude,
        longitude: longitude,
        mapsUrl: mapsUrl,
        infoUrl: infoUrl,
        source: normalizedSource,
        rating: rating,
      );
    }

    await updateCuisineTags(id, extraCuisineIds);
    await replaceRestaurantImages(id, images);

    return id;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  static final _secureRand = Random.secure();

  String _generateUUID() {
    final bytes = List<int>.generate(16, (_) => _secureRand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
        '-${hex.substring(20)}';
  }

  String? _extractStoragePath(String imageUrl, String bucket) {
    if (imageUrl.trim().isEmpty) return null;

    Uri uri;
    try {
      uri = Uri.parse(imageUrl);
    } catch (_) {
      return null;
    }

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(bucket);
    if (bucketIndex == -1 || bucketIndex + 1 >= segments.length) {
      return null;
    }

    return segments.sublist(bucketIndex + 1).join('/');
  }
}
