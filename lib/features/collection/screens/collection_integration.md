

# Collection Restaurant Rendering Integration Guideline

## Current Problem

The current collection detail flow is mainly built for post collections.

Restaurant collections can be saved into the database through `collections_item.restaurant_id`, but the current collection detail screen does not properly retrieve or render restaurants yet.

Current issue:

```text
collections_item.post_id        → retrieved and rendered as posts
collections_item.restaurant_id  → not retrieved/rendered properly yet
```

This means a restaurant collection may look empty even when rows exist in `collections_item`.

---

## Goal

Update the collection detail flow so it supports both collection types:

```text
POST collection       → retrieve post_id and render posts
RESTAURANT collection → retrieve restaurant_id and render restaurants
```

For restaurant collections, the UI should render saved restaurants using a design similar to the restaurant row in:

```text
lib/features/search/screens/search_result.dart
```

Use the existing search result restaurant row as the visual reference.

---

## Files to Focus On

```text
lib/features/collection/screens/collection_detail_screen.dart
lib/features/collection/screens/collection_integration.md
lib/data/repositories/collection_repository.dart
lib/data/repositories/restaurant_repository.dart
lib/data/models/collection_model.dart
lib/data/models/restaurant_model.dart
lib/features/restaurant/screens/restaurant_detail_screen.dart
lib/features/search/screens/search_result.dart
```

Only update files required for retrieving and rendering restaurant collection items.

Do not modify:

```text
BlindBox recommendation algorithm
BlindBox swipe behavior
SearchRepository ranking logic
Admin restaurant CRUD
Restaurant approval workflow
Post creation flow
```

---

## Database Context

The database stores collection items in:

```text
collections_item
```

Important columns:

```text
item_Id
collection_Id
restaurant_id
post_id
savedAt
```

For post collections:

```text
post_id is not null
restaurant_id is null
```

For restaurant collections:

```text
restaurant_id is not null
post_id is null
```

The parent collection table contains:

```text
collections.collection_type
```

Possible values:

```text
POST
RESTAURANT
```

Use this field to decide what to retrieve and render.

---

## Required Behavior

### POST collection

Keep the existing behavior.

```text
CollectionDetailScreen
  → retrieve collections_item.post_id
  → fetch/render posts
  → tap post opens PostDetailScreen
```

Do not break the current post collection UI.

### RESTAURANT collection

Add new behavior.

```text
CollectionDetailScreen
  → retrieve collections_item.restaurant_id
  → fetch/render Restaurant rows
  → tap restaurant opens RestaurantDetailScreen(restaurantId: ...)
```

A restaurant collection should not appear empty if `collections_item` contains restaurant IDs.

---

## Repository Requirement

Add restaurant retrieval support to `CollectionRepository`.

Recommended method:

```dart
Future<List<RestaurantModel>> getRestaurantsInCollection(String collectionId)
```

Conceptual implementation:

```text
1. Query collections_item by collection_Id.
2. Select restaurant_id.
3. Ignore null restaurant_id values.
4. Fetch matching Restaurant rows.
5. Return List<RestaurantModel>.
```

The restaurant fetch should include enough fields for the restaurant row UI:

```text
restaurant_Id
restaurant_name
address
main_cuisine_id
mainCuisine:Cuisine!restaurant_main_cuisine_fk(type_id, desc, isPrimaryOption)
Restaurant_Image(image_id, image_url, isCover)
rating
price_range
isDisabled
```

Use existing restaurant select strings or repository methods where possible.

If `RestaurantRepository` already has a suitable method for fetching multiple restaurants by IDs, reuse it. If not, add the collection-specific method in `CollectionRepository`.

---

## CollectionDetailScreen Branching

Update `CollectionDetailScreen` so it branches based on collection type.

Conceptual flow:

```dart
if (widget.collection.collectionType == CollectionType.post ||
    widget.collection.collectionType == 'POST') {
  await _loadPosts();
} else if (widget.collection.collectionType == CollectionType.restaurant ||
           widget.collection.collectionType == 'RESTAURANT') {
  await _loadRestaurants();
}
```

Use the actual type/field names from `CollectionModel`.

The screen should keep separate state for posts and restaurants, for example:

```dart
List<PostModel> _posts = [];
List<RestaurantModel> _restaurants = [];
bool _isLoading = false;
String? _errorMessage;
```

Do not mix post and restaurant rendering in one list unless the current UI already supports mixed collection items.

---

## Restaurant Rendering Design

For restaurant collection items, refer to the restaurant row design in:

```text
lib/features/search/screens/search_result.dart
```

Use a similar structure:

```text
row container/card
  → small restaurant cover image on the left
  → restaurant name
  → restaurant address
  → cuisine chip
```

The design should look visually consistent with search results.

### Suggested layout

```text
Restaurant row
├─ 56x56 cover image / placeholder
└─ text column
   ├─ restaurant name
   ├─ address
   └─ cuisine chip
```

### Data mapping

```text
cover image      → restaurant.imageUrls.first or cover image from Restaurant_Image
restaurant name  → restaurant.name
address          → restaurant.address
cuisine chip     → restaurant.mainCuisine?.description or fallback text
restaurant ID    → restaurant.restaurantId
```

Do not show raw cuisine UUID if a readable cuisine name exists.

Fallback order for cuisine text:

```dart
restaurant.mainCuisine?.description ?? restaurant.mainCuisineId ?? '-'
```

This matches the current safer restaurant row fallback used in `search_result.dart`.

---

## Restaurant Row Interaction

Each restaurant row in a restaurant collection should be tappable.

On tap:

```dart
Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (_) => RestaurantDetailScreen(
      restaurantId: restaurant.restaurantId,
    ),
  ),
);
```

Use the actual constructor of `RestaurantDetailScreen`.

If the collection screen is Material-based, use the project’s existing navigation style. If it already uses Cupertino routes elsewhere, use `CupertinoPageRoute`.

---

## Empty State

The empty state should depend on collection type.

For post collection:

```text
No saved posts yet.
```

For restaurant collection:

```text
No saved restaurants yet.
```

Do not show a post-specific empty state for restaurant collections.

---

## Loading State

Keep the existing loading style if it exists.

For restaurant collections, loading skeleton can follow the same restaurant-row skeleton style used in search results:

```text
image skeleton + name skeleton + address skeleton + cuisine chip skeleton
```

This keeps loading behavior visually consistent with `SearchResultScreen`.

---

## Error State

If restaurant retrieval fails, show a friendly error message.

Example:

```text
Unable to load saved restaurants. Please try again.
```

Do not crash if:

```text
restaurant_id is null
restaurant row no longer exists
restaurant is disabled
restaurant image is missing
main cuisine join is missing
```

For disabled or missing restaurants, either hide them or show only valid active restaurants, depending on the existing collection policy. Prefer hiding disabled/missing restaurants for user-facing collection display.

---

## Important Compatibility Notes

Do not break existing post collections.

The existing post collection logic should still:

```text
load saved posts
render post cards/grid
open post detail
support remove/unsave if already implemented
```

The new restaurant logic should be added alongside it, not replacing it.

---

## Optional Remove/Unsave Behavior

If the current collection detail screen supports removing posts from a collection, add similar support for restaurants later.

Possible repository method:

```dart
Future<void> removeRestaurantFromCollection({
  required String collectionId,
  required String restaurantId,
})
```

This is optional unless the current UI already exposes remove controls for collection items.

---

## Recommended Implementation Order

1. Inspect `CollectionModel` and confirm the field name for `collection_type`.
2. Add restaurant retrieval method in `CollectionRepository`.
3. Update `CollectionDetailScreen` state to hold restaurants.
4. Branch loading logic by collection type.
5. Keep existing post retrieval/rendering unchanged.
6. Add restaurant row renderer based on `search_result.dart` restaurant row design.
7. Add restaurant row tap navigation to `RestaurantDetailScreen`.
8. Add restaurant-specific empty/loading/error states.
9. Test both POST and RESTAURANT collections.

---

## Final Checks

Before completing, verify:

- Existing post collections still show posts.
- Restaurant collections retrieve `collections_item.restaurant_id`.
- Restaurant collections fetch matching `Restaurant` rows.
- Restaurant collections render restaurant rows.
- Restaurant row design is visually consistent with `search_result.dart`.
- Restaurant row tap opens `RestaurantDetailScreen` by restaurant ID.
- Restaurant collection empty state says restaurants, not posts.
- Missing images show a placeholder instead of crashing.
- Missing cuisine does not show raw UUID if readable cuisine text exists.
- Disabled/missing restaurants do not crash the collection page.