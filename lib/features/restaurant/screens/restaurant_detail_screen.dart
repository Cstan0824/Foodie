import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/collection_model.dart';
import 'package:taste_spot/data/repositories/collection_repository.dart';
import 'package:taste_spot/data/repositories/restaurant_repository.dart';
import 'package:taste_spot/features/search/screens/search_result.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? restaurant; // Mock fallback
  final String? restaurantId;
  final int initialImageIndex;

  const RestaurantDetailScreen({
    super.key,
    this.restaurant,
    this.restaurantId,
    this.initialImageIndex = 0,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late final PageController _pageController;
  int _currentImageIndex = 0;

  bool _isLoading = false;
  String? _errorMessage;
  RestaurantDetailData? _detail;

  double? _userLatitude;
  double? _userLongitude;

  bool _isSaved = false;
  bool _isSaveLoading = false;

  String? get _currentUserId => SupabaseService.currentUserId;

  String? get _resolvedRestaurantId {
    if (widget.restaurantId != null && widget.restaurantId!.isNotEmpty)
      return widget.restaurantId;
    if (_detail != null) return _detail!.restaurant.restaurantId;
    if (widget.restaurant != null)
      return widget.restaurant!['restaurant_Id']?.toString() ??
          widget.restaurant!['id']?.toString();
    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentImageIndex = widget.initialImageIndex;
    _pageController = PageController(initialPage: widget.initialImageIndex);

    _getCurrentLocation();

    if (widget.restaurantId != null && widget.restaurantId!.isNotEmpty) {
      _loadRestaurantDetail();
    }
    _checkSaveStatus();
  }

  Future<void> _checkSaveStatus() async {
    final userId = _currentUserId;
    final resId = _resolvedRestaurantId;
    if (userId == null || resId == null) return;

    try {
      final isSaved = await RestaurantRepository.instance.isRestaurantSaved(
        userId: userId,
        restaurantId: resId,
      );
      if (mounted) {
        setState(() => _isSaved = isSaved);
      }
    } catch (_) {}
  }

  void _showAuthRequiredDialog() {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Sign In Required'),
        content: const Text('Please sign in to continue.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSave() async {
    if (_isSaveLoading) return;
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredDialog();
      return;
    }
    final resId = _resolvedRestaurantId;
    if (resId == null) return;

    setState(() => _isSaveLoading = true);

    try {
      if (_isSaved) {
        await RestaurantRepository.instance.unsaveRestaurantForUser(
          userId: userId,
          restaurantId: resId,
        );
        if (mounted) setState(() => _isSaved = false);
      } else {
        await RestaurantRepository.instance.saveRestaurantToDefaultCollection(
          userId: userId,
          restaurantId: resId,
        );
        if (mounted) setState(() => _isSaved = true);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSaveLoading = false);
    }
  }

  void _showSaveSheet(BuildContext context) {
    final userId = _currentUserId;
    if (userId == null) {
      _showAuthRequiredDialog();
      return;
    }
    final resId = _resolvedRestaurantId;
    if (resId == null) return;

    final collectionRepo = CollectionRepository(SupabaseService.client);

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Save to Collection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Collection>>(
                  future: collectionRepo.getUserCollections(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error loading collections'),
                      );
                    }

                    final collections =
                        snapshot.data
                            ?.where((c) => c.collectionType == 'RESTAURANT')
                            .toList() ??
                        [];

                    if (collections.isEmpty) {
                      return const Center(
                        child: Text('No restaurant collections found.'),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: collections.length,
                      separatorBuilder: (_, __) => Container(
                        height: 1,
                        color: CupertinoColors.systemGrey5,
                      ),
                      itemBuilder: (context, index) {
                        final collection = collections[index];
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          onPressed: () async {
                            Navigator.pop(modalContext);
                            await _saveToSpecificCollection(
                              collection.collectionId,
                              resId,
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.folder_fill,
                                color: AppColors.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                collection.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToSpecificCollection(
    String collectionId,
    String resId,
  ) async {
    if (_isSaveLoading) return;
    setState(() => _isSaveLoading = true);

    try {
      await RestaurantRepository.instance.saveRestaurantToCollection(
        collectionId: collectionId,
        restaurantId: resId,
      );

      if (!_isSaved) {
        if (mounted) setState(() => _isSaved = true);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSaveLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRestaurantDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await RestaurantRepository.instance.fetchRestaurantDetail(
        widget.restaurantId!,
      );

      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _errorMessage = 'Restaurant not found.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load restaurant details.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openRelatedPosts(String name) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SearchResultScreen(initialQuery: 'restaurant: $name'),
      ),
    );
  }

  // --- Dynamic Getters ---

  String get _restaurantName {
    if (_detail != null) return _detail!.restaurant.name;
    if (widget.restaurant != null) {
      return (widget.restaurant!['restaurant_name'] ??
              widget.restaurant!['name'] ??
              'Restaurant')
          .toString();
    }
    return 'Restaurant';
  }

  String? get _description {
    if (_detail != null) return _detail!.restaurant.description;
    if (widget.restaurant != null) {
      final raw = (widget.restaurant!['description'] as String?)?.trim();
      return (raw == null || raw.isEmpty) ? null : raw;
    }
    return null;
  }

  String get _priceRange {
    if (_detail != null) return _detail!.restaurant.priceRange ?? '-';
    if (widget.restaurant != null) {
      return (widget.restaurant!['price_range'] ??
              widget.restaurant!['price'] ??
              '-')
          .toString();
    }
    return '-';
  }

  String? get _distanceText {
    if (_detail != null &&
        _userLatitude != null &&
        _userLongitude != null &&
        _detail!.restaurant.latitude != null &&
        _detail!.restaurant.longitude != null) {
      const earthRadiusKm = 6371.0;
      double degToRad(double degree) => degree * pi / 180.0;

      final userLat = _userLatitude!;
      final userLng = _userLongitude!;
      final restLat = _detail!.restaurant.latitude!;
      final restLng = _detail!.restaurant.longitude!;

      final dLat = degToRad(restLat - userLat);
      final dLng = degToRad(restLng - userLng);

      final a =
          sin(dLat / 2) * sin(dLat / 2) +
          cos(degToRad(userLat)) *
              cos(degToRad(restLat)) *
              sin(dLng / 2) *
              sin(dLng / 2);

      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      final distanceKm = earthRadiusKm * c;

      if (distanceKm < 1) {
        return '${(distanceKm * 1000).round()} m';
      }
      return '${distanceKm.toStringAsFixed(1)} km';
    }

    if (widget.restaurant != null) {
      final raw = widget.restaurant!['distance']?.toString().trim();
      return (raw == null || raw.isEmpty) ? null : raw;
    }
    return null;
  }

  String get _mainCuisine {
    if (_detail != null) {
      return _detail!.restaurant.mainCuisineId ?? 'Cuisine';
    }
    final list = _allCuisineTagsMock;
    return list.isEmpty ? 'Cuisine' : list.first;
  }

  List<String> get _extraCuisineTags {
    if (_detail != null) {
      return _detail!.extraCuisines
          .map((c) => c.description)
          .where((t) => t != _mainCuisine)
          .toList();
    }
    final list = _allCuisineTagsMock;
    return list.length <= 1 ? const [] : list.skip(1).toList();
  }

  String get _address {
    if (_detail != null)
      return _detail!.restaurant.address ?? 'Address unavailable';
    if (widget.restaurant != null) {
      final raw = (widget.restaurant!['address'] as String?)?.trim();
      return (raw == null || raw.isEmpty) ? 'Address unavailable' : raw;
    }
    return 'Address unavailable';
  }

  String? get _mapsUrl {
    if (_detail != null) return _detail!.restaurant.mapsUrl;
    if (widget.restaurant != null) {
      final raw =
          (widget.restaurant!['maps_url'] ?? widget.restaurant!['locationUrl'])
              ?.toString()
              .trim();
      return (raw == null || raw.isEmpty) ? null : raw;
    }
    return null;
  }

  String? get _websiteUrl {
    if (_detail != null) return _detail!.restaurant.infoUrl;
    if (widget.restaurant != null) {
      final raw = widget.restaurant!['info_url']?.toString().trim();
      return (raw == null || raw.isEmpty) ? null : raw;
    }
    return null;
  }

  String? get _ratingText {
    if (_detail != null) {
      final rating = _detail!.restaurant.rating;
      return rating == null ? null : rating.toString();
    }
    if (widget.restaurant != null) {
      final raw = widget.restaurant!['rating']?.toString().trim();
      return raw == null || raw.isEmpty || raw == '-' ? null : raw;
    }
    return null;
  }

  List<String> get _images {
    if (_detail != null) {
      if (_detail!.images.isNotEmpty) {
        return _detail!.images.map((e) => e.imageUrl).toList();
      }
      return _detail!.restaurant.imageUrls;
    }
    if (widget.restaurant != null) {
      return List<String>.from(
        widget.restaurant!['images'] ?? const <String>[],
      );
    }
    return [];
  }

  List<String> get _allCuisineTagsMock {
    if (widget.restaurant == null) return [];
    final tags = <String>[];
    final r = widget.restaurant!;

    final rawCuisines = r['cuisines'];
    if (rawCuisines is List) {
      for (final item in rawCuisines) {
        final text = item?.toString().trim();
        if (text != null && text.isNotEmpty && !tags.contains(text)) {
          tags.add(text);
        }
      }
    }

    final rawCuisine = (r['cuisine'] ?? r['main_cuisine'])?.toString().trim();
    if (rawCuisine != null && rawCuisine.isNotEmpty) {
      final split = rawCuisine
          .split('•')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      for (final item in split) {
        if (!tags.contains(item)) tags.add(item);
      }
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.white,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: CupertinoColors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
          middle: Text('Loading...'),
        ),
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_errorMessage != null) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.white,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: CupertinoColors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
          middle: Text('Error'),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final name = _restaurantName;
    final heroTag =
        'restaurant_image_${widget.restaurantId ?? (widget.restaurant?['id'] ?? name)}';
    final descriptionText =
        _description ?? 'No description available for this place yet.';
    final images = _images;
    final ratingText = _ratingText;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
        middle: Text(name),
        trailing: GestureDetector(
          onTap: _toggleSave,
          onLongPress: () => _showSaveSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: _isSaveLoading
                ? const CupertinoActivityIndicator(radius: 10)
                : Icon(
                    _isSaved
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    color: _isSaved ? AppColors.primary : AppColors.textPrimary,
                    size: 22,
                  ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: heroTag,
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            if (images.isEmpty)
                              Container(color: AppColors.surface)
                            else
                              PageView.builder(
                                controller: _pageController,
                                itemCount: images.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentImageIndex = index;
                                  });
                                },
                                itemBuilder: (_, index) {
                                  return Image.network(
                                    images[index],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              color: AppColors.surface,
                                              child: const Center(
                                                child: Icon(
                                                  CupertinoIcons.photo,
                                                  color: AppColors.textLight,
                                                ),
                                              ),
                                            ),
                                  );
                                },
                              ),
                            if (images.length > 1)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 12,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    images.length,
                                    (index) => AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      height: 6,
                                      width: _currentImageIndex == index
                                          ? 16
                                          : 6,
                                      decoration: BoxDecoration(
                                        color: _currentImageIndex == index
                                            ? CupertinoColors.white
                                            : CupertinoColors.white.withAlpha(
                                                130,
                                              ),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (ratingText != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    ratingText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (_distanceText != null) ...[
                                if (ratingText != null)
                                  const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _distanceText!,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_mainCuisine${_priceRange != '-' ? ' • $_priceRange' : ''}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_description != null) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'About this place',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              descriptionText,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                          if (_extraCuisineTags.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'More cuisines',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _extraCuisineTags
                                  .map(
                                    (tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(
                                          color: AppColors.divider,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 24),
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  CupertinoIcons.location_solid,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _address,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_mapsUrl != null || _websiteUrl != null) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (_mapsUrl != null)
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    onPressed: () =>
                                        _openExternalUrl(_mapsUrl!),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.map,
                                          size: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Open in Maps',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_websiteUrl != null)
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    onPressed: () =>
                                        _openExternalUrl(_websiteUrl!),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.globe,
                                          size: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Visit their website',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  border: const Border(
                    top: BorderSide(color: AppColors.divider, width: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () => _openRelatedPosts(name),
                    child: const Text('See Related Posts'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
