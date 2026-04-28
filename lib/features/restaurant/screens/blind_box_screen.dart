import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taste_spot/core/services/supabase_service.dart';
import 'package:taste_spot/core/theme/app_theme.dart';
import 'package:taste_spot/data/models/restaurant_model.dart';
import 'package:taste_spot/data/repositories/blind_box_repository.dart';
import 'restaurant_detail_screen.dart';
import 'swipe_history.dart';

class BlindBoxScreen extends StatefulWidget {
  const BlindBoxScreen({super.key});

  @override
  State<BlindBoxScreen> createState() => BlindBoxScreenState();
}

class BlindBoxScreenState extends State<BlindBoxScreen>
    with SingleTickerProviderStateMixin {
  // ── Sensor / Shake Logic ──
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  static const double _shakeThreshold = 30.0; // Sensitivity
  bool _isListening = true;
  bool _isFinding = false; // "Finding nearby..." state
  bool _hasFound = false; // "Show cards" state
  bool _hasDismissedInstructions = false;
  bool _doNotShowInstructionsAgain = false;
  static const String _hideInstructionsPreferenceKey =
      'blind_box_hide_instructions';

  // ── Swiper Logic ──
  final AppinioSwiperController _swiperController = AppinioSwiperController();
  List<RestaurantModel> _restaurants = [];
  String? _errorMessage;
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  Future<void> _showInstructions({bool manual = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final shouldHide = prefs.getBool(_hideInstructionsPreferenceKey) ?? false;

    if (!mounted) return;
    if (!manual && (shouldHide || _hasDismissedInstructions)) return;

    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var doNotShowAgain = shouldHide;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('How BlindBox works'),
              content: Column(
                children: [
                  const SizedBox(height: 8),
                  const _BlindBoxInstructionRow(
                    icon: CupertinoIcons.xmark_circle,
                    text: 'Swipe left to skip',
                  ),
                  const _BlindBoxInstructionRow(
                    icon: CupertinoIcons.heart_circle,
                    text: 'Swipe right to save',
                  ),
                  const _BlindBoxInstructionRow(
                    icon: CupertinoIcons.photo_on_rectangle,
                    text: 'Tap left/right to switch photos',
                  ),
                  const _BlindBoxInstructionRow(
                    icon: CupertinoIcons.info_circle,
                    text: 'Tap center to view restaurant',
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setDialogState(() {
                        doNotShowAgain = !doNotShowAgain;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          doNotShowAgain
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          size: 18,
                          color: doNotShowAgain
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Do not show again',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    if (doNotShowAgain) {
                      await prefs.setBool(_hideInstructionsPreferenceKey, true);
                    } else if (shouldHide) {
                      await prefs.setBool(
                        _hideInstructionsPreferenceKey,
                        false,
                      );
                    }
                    if (mounted) {
                      setState(() {
                        _hasDismissedInstructions = true;
                        _doNotShowInstructionsAgain = doNotShowAgain;
                      });
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Got it'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showInstructionsIfNeeded() async {
    await _showInstructions(manual: false);
  }

  @override
  void dispose() {
    _stopListening();
    _swiperController.dispose();
    super.dispose();
  }

  void _startListening() {
    _accelerometerSubscription = userAccelerometerEventStream().listen((
      UserAccelerometerEvent event,
    ) {
      if (!_isListening) return;

      // Calculate magnitude of acceleration
      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (acceleration > _shakeThreshold) {
        _handleShake();
      }
    });
  }

  void _stopListening() {
    _accelerometerSubscription?.cancel();
  }

  Future<Position?> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _handleShake() async {
    // Prevent multiple triggers
    if (_isFinding || _hasFound) return;

    setState(() {
      _isFinding = true; // Show loading animation
      _isListening = false; // Stop listening
      _errorMessage = null;
    });

    try {
      final position = await _getCurrentLocation();
      final userId = SupabaseService.client.auth.currentUser?.id ?? '';

      final restaurants = await BlindBoxRepository.instance
          .fetchRecommendations(
            userId: userId,
            userLatitude: position?.latitude,
            userLongitude: position?.longitude,
          );

      if (!mounted) return;

      setState(() {
        _userLatitude = position?.latitude;
        _userLongitude = position?.longitude;
        _restaurants = restaurants;
        _isFinding = false;
        _hasFound = true;
      });

      if (restaurants.isNotEmpty) {
        unawaited(_showInstructionsIfNeeded());
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isFinding = false;
        _hasFound = false;
        _errorMessage = 'Unable to load recommendations. Please try again.';
      });
    }
  }

  // Reset to initial state
  void reset() {
    setState(() {
      _hasFound = false;
      _isFinding = false;
      _isListening = true;
      _errorMessage = null;
      _restaurants = [];
      _hasDismissedInstructions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showInstructions(manual: true),
          child: const Icon(
            CupertinoIcons.info_circle,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
        middle: const Text(
          'Blind Box',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: CupertinoColors.white.withAlpha(
          240,
        ), // slightly transparent
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const BlindBoxSwipeHistoryScreen(),
                  ),
                );
              },
              child: const Icon(
                CupertinoIcons.time,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ),
            if (_hasFound)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: reset,
                child: const Icon(
                  CupertinoIcons.arrow_counterclockwise,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _hasFound
              ? _buildCardStack()
              : _isFinding
              ? _buildFindingAnimation()
              : _buildShakePrompt(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // UI 1: SHAKE PROMPT
  // ══════════════════════════════════════════
  Widget _buildShakePrompt() {
    return Center(
      key: const ValueKey('ShakePrompt'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.device_phone_portrait,
            size: 100,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 24),
          const Text(
            'Shake your phone!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'We\'ll find the best spots nearby\nfor a surprise meal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const SizedBox(height: 48),
          // Fallback button for simulator testing
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            onPressed: _handleShake,
            child: const Text(
              'Tap to Discover',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '(Use this if on Simulator)',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // UI 2: FINDING ANIMATION
  // ══════════════════════════════════════════
  Widget _buildFindingAnimation() {
    return const Center(
      key: ValueKey('Finding'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 20),
          SizedBox(height: 24),
          Text(
            'Finding nearby gems...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // UI 3: CARD STACK (TINDER-LIKE)
  // ══════════════════════════════════════════
  Widget _buildCardStack() {
    if (_restaurants.isEmpty) {
      return Center(
        key: const ValueKey('EmptyStack'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No restaurants found yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: reset,
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('CardStack'),
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: AppinioSwiper(
              controller: _swiperController,
              cardCount: _restaurants.length,
              backgroundCardCount: 0,
              maxAngle: 30,
              loop: true,
              onSwipeEnd: (previousIndex, targetIndex, activity) {
                if (activity is Swipe) {
                  final restaurant = _restaurants[previousIndex];
                  final userId =
                      SupabaseService.client.auth.currentUser?.id ?? '';
                  if (userId.isEmpty) return; // Silent if no user

                  if (activity.direction == AxisDirection.left) {
                    // Skip
                    BlindBoxRepository.instance
                        .recordSwipe(
                          userId: userId,
                          restaurantId: restaurant.restaurantId,
                        )
                        .catchError((_) {});
                  } else if (activity.direction == AxisDirection.right) {
                    // Save
                    BlindBoxRepository.instance
                        .recordSwipe(
                          userId: userId,
                          restaurantId: restaurant.restaurantId,
                        )
                        .catchError((_) {});

                    BlindBoxRepository.instance
                        .saveRestaurantToCollection(
                          userId: userId,
                          restaurantId: restaurant.restaurantId,
                        )
                        .catchError((_) {});
                  }
                }
              },
              cardBuilder: (context, index) {
                final restaurant = _restaurants[index];
                return _RestaurantCard(
                  key: ValueKey(restaurant.restaurantId),
                  restaurant: restaurant,
                  userLatitude: _userLatitude,
                  userLongitude: _userLongitude,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BlindBoxInstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BlindBoxInstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatefulWidget {
  final RestaurantModel restaurant;
  final double? userLatitude;
  final double? userLongitude;

  const _RestaurantCard({
    super.key,
    required this.restaurant,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<_RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<_RestaurantCard> {
  int _currentImageIndex = 0;

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final double tapPosition = details.localPosition.dx;
    final double width = constraints.maxWidth;
    final images = widget.restaurant.imageUrls;

    if (tapPosition < width * 0.3) {
      // Tap left: previous image
      if (_currentImageIndex > 0) {
        setState(() {
          _currentImageIndex--;
        });
      }
    } else if (tapPosition > width * 0.7) {
      // Tap right: next image
      if (_currentImageIndex < images.length - 1) {
        setState(() {
          _currentImageIndex++;
        });
      }
    } else {
      // Tap center: navigate to details
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => RestaurantDetailScreen(
            restaurantId: widget.restaurant.restaurantId,
            initialImageIndex: _currentImageIndex,
          ),
        ),
      );
    }
  }

  String? _getDistance() {
    if (widget.userLatitude == null ||
        widget.userLongitude == null ||
        widget.restaurant.latitude == null ||
        widget.restaurant.longitude == null) {
      return null;
    }

    const earthRadiusKm = 6371.0;
    double degToRad(double degree) => degree * pi / 180.0;

    final userLat = widget.userLatitude!;
    final userLng = widget.userLongitude!;
    final restLat = widget.restaurant.latitude!;
    final restLng = widget.restaurant.longitude!;

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

  @override
  Widget build(BuildContext context) {
    final images = widget.restaurant.imageUrls;
    final distance = _getDistance();
    final rating = widget.restaurant.rating?.toStringAsFixed(1) ?? 'New';
    final cuisine = widget.restaurant.mainCuisineId ?? 'Restaurant';
    final priceRange = widget.restaurant.priceRange ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) => _handleTap(details, constraints),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: CupertinoColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Full Background Image
                  Positioned.fill(
                    child: images.isNotEmpty
                        ? Hero(
                            tag:
                                'restaurant_image_${widget.restaurant.restaurantId}',
                            child: Image.network(
                              images[_currentImageIndex],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: AppColors.surface,
                                    child: const Center(
                                      child: Icon(
                                        CupertinoIcons.photo,
                                        size: 50,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ),
                            ),
                          )
                        : Container(
                            color: AppColors.surface,
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                size: 50,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                  ),

                  // Image Indicators (Bars at the top)
                  if (images.length > 1)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: List.generate(images.length, (index) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 4,
                              decoration: BoxDecoration(
                                color: index == _currentImageIndex
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                  // Gradient Overlay for Text Visibility
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.8),
                          ],
                          stops: const [0.5, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Info Content
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
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
                                rating,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (distance != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  distance,
                                  style: const TextStyle(
                                    color: Colors.white,
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
                          widget.restaurant.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$cuisine${priceRange.isNotEmpty ? ' • $priceRange' : ''}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
