import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import '../../core/theme/app_theme.dart';
import 'restaurant_detail_screen.dart';

class BlindBoxScreen extends StatefulWidget {
  const BlindBoxScreen({super.key});

  @override
  State<BlindBoxScreen> createState() => _BlindBoxScreenState();
}

class _BlindBoxScreenState extends State<BlindBoxScreen> with SingleTickerProviderStateMixin {
  // ── Sensor / Shake Logic ──
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  static const double _shakeThreshold = 30.0; // Sensitivity
  bool _isListening = true;
  bool _isFinding = false; // "Finding nearby..." state
  bool _hasFound = false;  // "Show cards" state

  // ── Swiper Logic ──
  final AppinioSwiperController _swiperController = AppinioSwiperController();
  final List<Map<String, dynamic>> _restaurants = [
    {
      'name': 'Sakura Sushi Bar',
      'images': [
        'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=800&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1553621042-f6e147245754?q=80&w=800&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1583623025817-d180a2221d0a?q=80&w=800&auto=format&fit=crop',
      ],
      'rating': 4.8,
      'cuisine': 'Japanese • Sushi',
      'distance': '0.5 km',
      'price': '\$\$\$',
      'menu': [
        {'name': 'Omakase Set', 'price': '\$85'},
        {'name': 'Dragon Roll', 'price': '\$18'},
        {'name': 'Spicy Tuna', 'price': '\$14'},
      ],
      'locationUrl': 'https://maps.google.com/?q=Sakura+Sushi+Bar',
    },
    {
      'name': 'The Burger Lab',
      'images': [
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=800&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1550547660-d9450f859349?q=80&w=800&auto=format&fit=crop',
      ],
      'rating': 4.5,
      'cuisine': 'American • Burgers',
      'distance': '1.2 km',
      'price': '\$\$',
      'menu': [
        {'name': 'Classic Cheeseburger', 'price': '\$12'},
        {'name': 'Truffle Fries', 'price': '\$8'},
        {'name': 'Milkshake', 'price': '\$6'},
      ],
      'locationUrl': 'https://maps.google.com/?q=The+Burger+Lab',
    },
    {
      'name': 'Mama\'s Pasta',
      'images': [
        'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?q=80&w=800&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1551183053-bf91a1d81141?q=80&w=800&auto=format&fit=crop',
      ],
      'rating': 4.7,
      'cuisine': 'Italian • Pasta',
      'distance': '2.4 km',
      'price': '\$\$',
      'menu': [
        {'name': 'Carbonara', 'price': '\$16'},
        {'name': 'Margherita Pizza', 'price': '\$18'},
        {'name': 'Tiramisu', 'price': '\$9'},
      ],
      'locationUrl': 'https://maps.google.com/?q=Mamas+Pasta',
    },
    {
      'name': 'Spicy Wok',
      'images': [
        'https://images.unsplash.com/photo-1555126634-323283e090fa?q=80&w=800&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1541614101331-1a5a3a194e92?q=80&w=800&auto=format&fit=crop',
      ],
      'rating': 4.2,
      'cuisine': 'Chinese • Spicy',
      'distance': '0.8 km',
      'price': '\$',
      'menu': [
        {'name': 'Kung Pao Chicken', 'price': '\$14'},
        {'name': 'Mapo Tofu', 'price': '\$12'},
        {'name': 'Spring Rolls', 'price': '\$6'},
      ],
      'locationUrl': 'https://maps.google.com/?q=Spicy+Wok',
    },
    {
      'name': 'Café  Mocha',
      'images': [
        'https://images.unsplash.com/photo-1521017432531-fbd92d768814?q=80&w=800&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1497935586351-b67a49e012bf?q=80&w=800&auto=format&fit=crop',
      ],
      'rating': 4.6,
      'cuisine': 'Café • Coffee',
      'distance': '0.3 km',
      'price': '\$',
      'menu': [
        {'name': 'Latte', 'price': '\$5'},
        {'name': 'Avocado Toast', 'price': '\$11'},
        {'name': 'Croissant', 'price': '\$4'},
      ],
      'locationUrl': 'https://maps.google.com/?q=Cafe+Mocha',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _stopListening();
    _swiperController.dispose();
    super.dispose();
  }

  void _startListening() {
    _accelerometerSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      if (!_isListening) return;

      // Calculate magnitude of acceleration
      double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      if (acceleration > _shakeThreshold) {
        _handleShake();
      }
    });
  }

  void _stopListening() {
    _accelerometerSubscription?.cancel();
  }

  void _handleShake() {
    // Prevent multiple triggers
    if (_isFinding || _hasFound) return;

    setState(() {
      _isFinding = true; // Show loading animation
      _isListening = false; // Stop listening
    });

    // Simulate network delay / "Finding" animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isFinding = false;
          _hasFound = true; // Show card stack
        });
      }
    });
  }

  // Reset to initial state
  void _reset() {
    setState(() {
      _hasFound = false;
      _isFinding = false;
      _isListening = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Blind Box', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: CupertinoColors.white.withAlpha(240), // slightly transparent
        border: null,
        trailing: _hasFound
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _reset,
                child: const Icon(CupertinoIcons.arrow_counterclockwise, size: 22, color: AppColors.textPrimary),
              )
            : null,
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _hasFound ? _buildCardStack() : _isFinding ? _buildFindingAnimation() : _buildShakePrompt(),
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
          Icon(
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
          const SizedBox(height: 48),
          // Fallback button for simulator testing
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            onPressed: _handleShake,
            child: const Text('Tap to Discover', style: TextStyle(fontWeight: FontWeight.w600)),
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
    return Center(
      key: const ValueKey('Finding'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 20),
          const SizedBox(height: 24),
          const Text(
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
    return Column(
      key: const ValueKey('CardStack'),
      children: [
        // Removed top spacing to stretch vertically
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10), // Added back horizontal spacing
            child: AppinioSwiper(
              controller: _swiperController,
              cardCount: _restaurants.length,
              backgroundCardCount: 0, // Turn off background cards stack
              maxAngle: 30, // Rotation during swipe
              loop: true,   // Loop back when finished
              
              cardBuilder: (context, index) {
                final restaurant = _restaurants[index];
                return _RestaurantCard(
                  key: ValueKey(restaurant['id']), // Add key to force rebuild on new card
                  restaurant: restaurant,
                );
              },
            ),
          ),
        ),
        // Removed bottom spacing to stretch vertically
      ],
    );
  }

  // Removed _buildActionButton since buttons are hidden
}

class _RestaurantCard extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  const _RestaurantCard({super.key, required this.restaurant});

  @override
  State<_RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<_RestaurantCard> {
  int _currentImageIndex = 0;

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final double tapPosition = details.localPosition.dx;
    final double width = constraints.maxWidth;
    final List<String> images = List<String>.from(widget.restaurant['images'] ?? []);

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
            restaurant: widget.restaurant,
            initialImageIndex: _currentImageIndex,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = List<String>.from(widget.restaurant['images'] ?? []);
    
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
                            tag: 'restaurant_image_${widget.restaurant['id']}',
                            child: Image.network(
                              images[_currentImageIndex],
                              fit: BoxFit.cover,
                            ),
                          )
                        : const SizedBox(),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${widget.restaurant['rating']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.restaurant['distance'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.restaurant['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.restaurant['cuisine']} • ${widget.restaurant['price']}',
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