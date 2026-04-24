# BlindBox Dynamic Integration Guideline

## Current Status

The BlindBox recommendation algorithm is already implemented in:

```text
lib/data/repositories/blind_box_repository.dart
```

The repository already supports rule-based restaurant recommendation using:

```text
current location, if available
user saved-restaurant cuisine preferences
main cuisine and extra cuisine scoring
restaurant newness
controlled tier-based randomization
```

The dependency and platform permissions for device location have already been added:

```text
Android permission: done
iOS permission: done
geolocator dependency: done
```

Location should be treated as an optional bonus input.

If location is available, BlindBox should use it for distance-based recommendation and distance display.

If location is unavailable or denied, BlindBox should still work using non-location scoring such as preference and newness.

---

## Main Goal

Convert the existing mock-data `blind_box_screen.dart` into a dynamic screen powered by `BlindBoxRepository`.

The new data flow should be:

```text
BlindBoxScreen
  → get optional device location
  → BlindBoxRepository.fetchRecommendations(...)
  → receive List<RestaurantModel>
  → show real restaurant cards
  → swipe left records swipe history as skip
  → swipe right records swipe history and saves restaurant into default restaurant collection
  → tap card opens RestaurantDetailScreen(restaurantId: ...)
  → tap left/right side of image switches restaurant images if available
```

The old mock restaurant map list should be removed or isolated as a temporary fallback only if needed for development.

---

## Files to Focus On

```text
lib/features/restaurant/screens/blind_box_screen.dart
lib/data/repositories/blind_box_repository.dart
lib/data/models/restaurant_model.dart
lib/features/restaurant/screens/restaurant_detail_screen.dart
```

Only update other files if compilation requires small import/model compatibility fixes.

Do not modify:

```text
admin restaurant CRUD
restaurant approval workflow
search ranking logic
post creation flow
restaurant detail layout, unless constructor compatibility is needed
```

---

## Repository Contract

Use:

```dart
BlindBoxRepository.instance.fetchRecommendations(
  userId: userId,
  userLatitude: latitude,
  userLongitude: longitude,
  cuisineId: optionalCuisineId,
)
```

Adjust argument names based on the actual method signature.

The repository should return:

```dart
List<RestaurantModel>
```

The latest repository select already includes the required card fields:

```text
restaurant_Id
restaurant_name
description
price_range
address
latitude
longitude
maps_url
main_cuisine_id
source
info_url
isDisabled
rating
created_At
mainCuisine
Restaurant_Image
```

So the BlindBox card can display:

```text
restaurant images
restaurant name
rating
main cuisine
price range
distance, if device location is available
```

---

## Replace Mock Data

The current screen is still based on mock data similar to:

```dart
final List<Map<String, dynamic>> _restaurants = [ ... ];
```

Replace this with dynamic state:

```dart
List<RestaurantModel> _restaurants = [];
bool _isLoadingRecommendations = false;
String? _errorMessage;
double? _userLatitude;
double? _userLongitude;
```

If the existing screen already has states such as `_isFinding`, `_hasFound`, or `_isListening`, keep them and connect the dynamic loading flow into them.

Recommended state meaning:

```text
_isListening   → initial shake/tap prompt is active
_isFinding     → recommendation loading animation is active
_hasFound      → recommendation cards should be displayed
_restaurants   → real recommended restaurants from repository
_errorMessage  → loading/location/repository failure message
_userLatitude  → current device latitude, nullable
_userLongitude → current device longitude, nullable
```

---

## Device Location Helper

Add a helper in `BlindBoxScreen` to safely get current device location.

Use `geolocator`.

Suggested helper:

```dart
Future<Position?> _getCurrentLocation() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) {
    return null;
  }

  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied) {
    return null;
  }

  if (permission == LocationPermission.deniedForever) {
    return null;
  }

  return Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
```

Important rules:

```text
Do not crash if location is unavailable.
Do not force the user to grant location before using BlindBox.
Do not fake a distance value.
If location is not available, hide distance or show a neutral non-distance label.
```

---

## Dynamic Recommendation Loading Flow

The existing mock screen probably has a method similar to:

```dart
_handleShake()
```

or a tap/shake action that starts the finding animation.

Convert that flow to:

```text
1. User shakes/taps to discover.
2. Set `_isFinding = true`.
3. Try to get device location.
4. Call `BlindBoxRepository.fetchRecommendations(...)`.
5. Store returned restaurants in `_restaurants`.
6. Store location coordinates if available.
7. Set `_hasFound = true`.
8. Stop loading animation.
```

Suggested structure:

```dart
Future<void> _loadRecommendations() async {
  if (_isFinding) return;

  setState(() {
    _isFinding = true;
    _isListening = false;
    _errorMessage = null;
  });

  try {
    final position = await _getCurrentLocation();

    final restaurants = await BlindBoxRepository.instance.fetchRecommendations(
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
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isFinding = false;
      _hasFound = false;
      _errorMessage = 'Unable to load recommendations. Please try again.';
    });
  }
}
```

Adjust the method name and arguments based on the current screen code.

If your repository requires `userId`, obtain it from the existing auth/session service used in the project. If there is no current user ID available yet, call the repository in the supported anonymous/default mode if the method allows it.

---

## Empty Recommendation Handling

If the repository returns an empty list:

```dart
if (restaurants.isEmpty) { ... }
```

show a friendly empty state instead of the card stack.

Suggested message:

```text
No restaurants found yet. Try again later.
```

If location was denied, do not say the failure is because of location unless the repository truly requires location.

Remember: location is optional.

---

## Card Data Mapping

Replace mock map access like:

```dart
restaurant['name']
restaurant['images']
restaurant['rating']
restaurant['cuisine']
restaurant['price']
restaurant['distance']
```

with `RestaurantModel` fields.

Conceptual mapping:

```text
restaurant['name']       → restaurant.name / restaurant.restaurantName
restaurant['images']     → restaurant.images / Restaurant_Image list
restaurant['rating']     → restaurant.rating
restaurant['cuisine']    → restaurant.mainCuisine?.desc
restaurant['price']      → restaurant.priceRange
restaurant['distance']   → calculate using user location + restaurant lat/lng
restaurant['locationUrl']→ restaurant.mapsUrl
```

Use the actual property names from `RestaurantModel`.

Avoid displaying raw UUID values such as `main_cuisine_id`.

---

## Restaurant Images on Card

Use the restaurant images returned by the model.

Expected source:

```text
Restaurant_Image(image_id, image_url, isCover)
```

Card image behavior:

```text
cover image should appear first
remaining images can follow
if no image exists, show a placeholder
```

Suggested helper concept:

```dart
List<String> _restaurantImageUrls(RestaurantModel restaurant) {
  final images = restaurant.images;

  final sorted = [...images]..sort((a, b) {
    if (a.isCover == b.isCover) return 0;
    return a.isCover ? -1 : 1;
  });

  return sorted.map((image) => image.imageUrl).toList();
}
```

Adjust based on the actual image model fields.

Do not crash if `images` is null or empty.

---

## Distance Display

Distance is based on current mobile device location.

The repository already uses distance internally for scoring when latitude/longitude are passed in.

For display, calculate distance in the screen/card using:

```text
user latitude/user longitude
restaurant latitude/restaurant longitude
```

Only show distance if all four values exist:

```text
userLatitude
userLongitude
restaurant.latitude
restaurant.longitude
```

Suggested display logic:

```text
if distance < 1 km → show meters, e.g. 450 m
if distance >= 1 km → show kilometers, e.g. 2.4 km
if location unavailable → hide the distance chip
```

Suggested helper:

```dart
double _distanceKm({
  required double userLat,
  required double userLng,
  required double restaurantLat,
  required double restaurantLng,
}) {
  const earthRadiusKm = 6371.0;

  double degToRad(double degree) => degree * pi / 180.0;

  final dLat = degToRad(restaurantLat - userLat);
  final dLng = degToRad(restaurantLng - userLng);

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(degToRad(userLat)) *
          cos(degToRad(restaurantLat)) *
          sin(dLng / 2) *
          sin(dLng / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

String _formatDistance(double km) {
  if (km < 1) {
    return '${(km * 1000).round()} m';
  }

  return '${km.toStringAsFixed(1)} km';
}
```

This helper requires:

```dart
import 'dart:math';
```

If `BlindBoxRepository` already exposes a distance helper publicly, reuse it instead of duplicating.

---

## Card UI Requirements

Keep the existing card design as much as possible.

The card should now display real dynamic values:

```text
image carousel or hero image from restaurant images
rating from restaurant.rating
restaurant name from restaurant name field
main cuisine from restaurant.mainCuisine.desc
price range from restaurant.priceRange
distance only when device location exists
```

If a value is missing:

```text
rating missing      → hide rating or show a neutral placeholder such as "New"
price range missing → hide price range
main cuisine missing→ hide cuisine or show "Restaurant"
image missing       → show placeholder image/container
distance missing    → hide distance
```

Do not display `null`, empty strings, or raw IDs in the UI.

---

## AppinioSwiper Integration

The current mock card stack likely uses:

```dart
AppinioSwiper(
  cardCount: _restaurants.length,
  cardBuilder: ...
)
```

Keep this structure, but `_restaurants` should now be:

```dart
List<RestaurantModel>
```

Card builder should pass the real restaurant model:

```dart
_RestaurantCard(
  restaurant: _restaurants[index],
  userLatitude: _userLatitude,
  userLongitude: _userLongitude,
)
```

Adjust names based on the current card widget.

---
## Swipe and Save Behavior

Both left swipe and right swipe must store swipe history through `BlindBoxRepository`.

Use the existing swipe-history method in `BlindBoxRepository`, similar to:

```dart
recordSwipe(...)
```

Use the existing restaurant save method in `BlindBoxRepository`, similar to:

```dart
saveRestaurantToCollection(...)
```

Do not use `CollectionRepository` directly from `BlindBoxScreen` for this feature. Keep the BlindBox interaction flow centralized through `BlindBoxRepository`.

### Required gesture behavior

```text
swipe left  → skip restaurant
            → record swipe history only
            → move to next card

swipe right → accept/save restaurant
            → record swipe history
            → save restaurant into the user's default restaurant collection
            → move to next card

tap card/body → open RestaurantDetailScreen by restaurant ID

tap left side of image  → show previous restaurant image, if available
tap right side of image → show next restaurant image, if available
```

### Swipe left flow

Conceptual flow:

```text
current card restaurant
  → get restaurant.restaurantId
  → get current user ID/session user ID
  → call BlindBoxRepository.recordSwipe(...)
  → continue to next card
```

The left swipe should not save the restaurant into any collection.

### Swipe right flow

Conceptual flow:

```text
current card restaurant
  → get restaurant.restaurantId
  → get current user ID/session user ID
  → call BlindBoxRepository.recordSwipe(...)
  → call BlindBoxRepository.saveRestaurantToCollection(...)
  → continue to next card
```

The right swipe should save the restaurant into the user's default restaurant collection.

If the restaurant is already saved, treat the save as success and keep the UI stable. Do not crash because of duplicate collection records.

### User ID requirement

Swipe history and saving need a user ID.

Use the existing auth/session service in the project to get the current user ID.

If user ID is unavailable, handle it explicitly:

```text
show a friendly login-required message
or prevent BlindBox from starting until login is available
or use the existing app auth flow to obtain the current user ID
```

Do not silently skip swipe history for logged-in users.

Do not treat swipe history as optional in the final implementation.

A repository error while recording swipe history or saving should not crash the screen. Show friendly feedback or log the error, but keep the UI stable.

---


## Card Tap and Image Tap Zones

The card needs separate tap behavior from image navigation.

Required behavior:

```text
tap card/body or non-image content → open RestaurantDetailScreen
tap left side of image             → previous image
tap right side of image            → next image
```

If the restaurant has only one image, left/right image taps can do nothing.

If the restaurant has no image, show the placeholder and let the normal card/body tap open `RestaurantDetailScreen`.

Do not let image left/right taps accidentally trigger restaurant-detail navigation.

Do not let normal card tap accidentally swipe/save/skip.

The image carousel state should be local to each card, for example:

```dart
int _currentImageIndex = 0;
```

When tapping right:

```text
if current image is not last → show next image
else → stay at last image or wrap only if existing design wants wraparound
```

When tapping left:

```text
if current image is not first → show previous image
else → stay at first image or wrap only if existing design wants wraparound
```

Keep the existing visual design as much as possible.

---

## Navigation to RestaurantDetailScreen

The BlindBox card should open the dynamic restaurant detail page.

Replace the old mock navigation:

```dart
RestaurantDetailScreen(
  restaurant: widget.restaurant,
  initialImageIndex: _currentImageIndex,
)
```

with ID-based navigation:

```dart
RestaurantDetailScreen(
  restaurantId: restaurant.restaurantId,
  initialImageIndex: currentImageIndex,
)
```

Use the actual constructor that already exists in `restaurant_detail_screen.dart`.

If the detail page does not support `initialImageIndex` anymore, remove that argument.

Expected flow:

```text
BlindBox card tap
  → RestaurantDetailScreen(restaurantId: selectedRestaurant.restaurantId)
  → detail page fetches full restaurant detail dynamically
```

Do not pass mock maps into the detail page anymore.

---

## Recommended Implementation Order

1. Replace mock `_restaurants` list with `List<RestaurantModel>` state.
2. Add optional location helper using `geolocator`.
3. Connect shake/tap discover action to dynamic repository loading.
4. Update the card widget to accept `RestaurantModel` instead of `Map<String, dynamic>`.
5. Map restaurant images, rating, main cuisine, price range, and distance into the card UI.
6. Add card tap behavior: center/body tap opens `RestaurantDetailScreen(restaurantId: ...)`.
7. Add image tap behavior: left/right image taps switch restaurant images.
8. Add empty/error states.
9. Wire required left-swipe behavior: record swipe history only.
10. Wire required right-swipe behavior: record swipe history and save restaurant through `BlindBoxRepository`.

---

## Final Expected User Flow

After implementation:

```text
1. User opens BlindBox.
2. User shakes or taps to discover.
3. App optionally asks for location permission.
4. If location is granted, recommendations consider nearby restaurants and cards show distance.
5. If location is denied, recommendations still load without distance.
6. App fetches real restaurants from BlindBoxRepository.
7. Cards show real images, rating, cuisine, price range, and optional distance.
8. User taps left/right side of the image to browse restaurant images, if available.
9. User swipes left to skip; app records swipe history and moves to the next card.
10. User swipes right to save; app records swipe history, saves the restaurant into the default restaurant collection, and moves to the next card.
11. User taps the card/body; app opens RestaurantDetailScreen using the restaurant ID.
12. RestaurantDetailScreen loads full restaurant data dynamically.
```

---

## Final Checks

Before completing, verify:

- BlindBox no longer depends on the hardcoded mock restaurant list.
- Recommendations come from `BlindBoxRepository.fetchRecommendations()`.
- Location permission denied does not break BlindBox.
- Cards show real restaurant image(s), rating, main cuisine, and price range.
- Distance only appears when real user location and restaurant coordinates are available.
- No fake distance is shown.
- No raw cuisine UUID is shown.
- Card tap opens `RestaurantDetailScreen` by restaurant ID.
- Swipe left records swipe history through `BlindBoxRepository` and does not save the restaurant.
- Swipe right records swipe history through `BlindBoxRepository` and saves the restaurant into the default restaurant collection.
- Swipe history is not silently skipped for logged-in users.
- Right-swipe save does not crash if the restaurant is already saved.
- Tapping left/right side of the image changes restaurant images without opening detail.
- Tapping the card/body opens `RestaurantDetailScreen` without saving/skipping.
- Restaurant detail still loads dynamically.
- Empty recommendation result shows a friendly message.
- Repository errors show a friendly retry/error state.