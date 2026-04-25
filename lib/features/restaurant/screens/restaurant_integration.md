

# Search Repository Follow-up Guideline: Return Restaurant Row for `restaurant: <restaurant-name>`

## Current Status

The previous task is done.

`SearchRepository` now supports the special query format:

```text
restaurant: <restaurant-name>
```

Example:

```text
restaurant: Sushi Nori
```

This scoped query is used by `RestaurantDetailScreen` when the user taps **See Related Posts**.

Current flow:

```text
RestaurantDetailScreen
  → See Related Posts
  → SearchResultScreen(initialQuery: "restaurant: Sushi Nori")
  → SearchRepository detects restaurant-scoped query
  → returns related posts
```

---

## Current Problem

The scoped restaurant query currently returns related posts, but it does not return the matched restaurant row.

The payload is currently conceptually like:

```dart
SearchResultsPayload(
  restaurants: [],
  posts: relatedPosts,
)
```

This means `SearchResultScreen` cannot show the restaurant preview/header row when the user lands on related posts from the restaurant detail page.

---

## New Goal

Update the restaurant-scoped search logic so that:

```text
restaurant: <restaurant-name>
```

returns both:

```dart
restaurants: [matchedRestaurant]
posts: [posts linked to matchedRestaurant]
```

Expected payload concept:

```dart
SearchResultsPayload(
  restaurants: [matchedRestaurantSearchResult],
  posts: relatedPosts,
)
```

This keeps the related-post search page connected to the selected restaurant context.

---

## Expected User Flow

After this update:

```text
1. User opens RestaurantDetailScreen.
2. User taps See Related Posts.
3. App opens SearchResultScreen(initialQuery: "restaurant: Sushi Nori").
4. SearchRepository detects the restaurant-scoped query.
5. SearchRepository finds the matching restaurant row.
6. SearchRepository fetches posts linked to that restaurant.
7. SearchResultScreen shows the matched restaurant preview row and related posts.
```

---

## Files to Focus On

```text
lib/data/repositories/search_repository.dart
lib/features/search/screens/search_result_screen.dart
```

The main change should be inside `SearchRepository`.

Only update `SearchResultScreen` if it needs a small display adjustment to show the returned restaurant row correctly.

Do not modify:

```text
admin CRUD
restaurant approval
BlindBox
post creation
restaurant detail layout
```

---

## Required Behavior

For normal search queries, keep existing behavior unchanged.

Examples:

```text
sushi
ramen setapak
japanese food
#dessert
```

For restaurant-scoped queries:

```text
restaurant: Sushi Nori
```

The repository should:

1. Extract `Sushi Nori` from the query.
2. Find the best matching restaurant row.
3. Convert that restaurant row into the same restaurant result type used by normal search.
4. Fetch posts linked to that restaurant.
5. Return both the matched restaurant and related posts.

---

## Important Implementation Direction

Do not only search posts by restaurant name.

Preferred logic:

```text
restaurant name from scoped query
  → find matched Restaurant row
  → use Restaurant.restaurant_Id
  → fetch posts by restaurant ID
  → return matched restaurant row + linked posts
```

This is better than filtering posts by restaurant name only, because restaurant names can duplicate and restaurant ID is the real relationship key.

---

## Matching the Restaurant Row

When searching for the restaurant row, use this priority:

### 1. Exact case-insensitive match

Example:

```text
restaurant: Sushi Nori
```

should first try to match:

```text
Restaurant.restaurant_name == Sushi Nori
```

case-insensitively.

### 2. Normalized exact match

If direct exact match is not possible, compare normalized names.

Example:

```text
sushi nori
Sushi Nori
SUSHI NORI
```

should be treated as the same.

### 3. Partial match fallback

Only if exact/normalized matching returns no result, allow partial matching.

Example:

```text
restaurant: Sushi
```

may match:

```text
Sushi Nori
```

Do not return multiple unrelated restaurant rows for this scoped query unless the existing result payload intentionally supports multiple restaurant matches.

For this task, prefer returning the single best matched restaurant row.

---

## Restaurant Result Mapping

The matched restaurant row should be converted into the same restaurant search result model/type used by the normal search flow.

Do not create a separate UI-only restaurant object if the repository already has an existing result model.

Use existing mapping helpers where possible.

The restaurant result should contain enough data for `SearchResultScreen` preview display:

```text
restaurant ID
restaurant name
main cuisine name
address
rating
price range
cover image if available
match/relevance score if required by the existing model
```

Avoid showing raw `main_cuisine_id` UUID in the UI.

---

## Post Fetching Rule

After the matched restaurant row is found, fetch posts through the linked restaurant ID.

Conceptual filter:

```text
Post.restaurant_id == matchedRestaurant.restaurant_Id
```

Use the actual database column/model field names in the current codebase.

Possible field names may include:

```text
restaurant_id
restaurant_Id
restaurantId
```

Only include posts that satisfy the existing post eligibility rules, such as:

```text
visible
not blocked
not removed
linked to a valid restaurant
```

Reuse existing post eligibility filtering and post mapping logic where possible.

---

## Result Payload Behavior

For:

```text
restaurant: Sushi Nori
```

return:

```dart
SearchResultsPayload(
  restaurants: [matchedRestaurant],
  posts: relatedPosts,
)
```

If no matching restaurant row is found:

```dart
SearchResultsPayload(
  restaurants: [],
  posts: [],
)
```

Do not fall back to broad keyword search automatically unless the existing UX explicitly expects fallback behavior.

A scoped query should stay scoped.

---

## SearchResultScreen Behavior

If `SearchResultScreen` is in `All` mode, it should be able to show:

```text
matched restaurant preview
related posts below
```

If the user switches to `Restaurants`, it should show the matched restaurant row.

If the user switches to `Posts`, it should show the related posts.

If this already works because the payload now contains `restaurants`, do not modify the screen.

Only make small UI adjustments if needed.

---

## Sort Behavior

Keep existing scoped-query sort behavior for posts.

### Top

Use existing post ranking or engagement/relevance logic.

### Latest

Sort related posts by newest first.

### Nearby

For restaurant-scoped related posts, nearby may not change the result much because all posts are linked to the same restaurant.

Acceptable behavior:

```text
fallback to Top
```

or:

```text
keep the existing scoped-query ordering
```

Do not invent distance values.

---

## Edge Cases

### Empty scoped query

```text
restaurant:
```

Return empty results safely.

### Unknown restaurant

```text
restaurant: Some Restaurant That Does Not Exist
```

Return:

```dart
restaurants: []
posts: []
```

Do not crash.

### Duplicate restaurant names

If multiple restaurant rows have the same or very similar name, select the best match using existing ranking rules if available.

Preferred tie-breakers:

```text
active / not disabled first
exact name match first
higher restaurant relevance score if available
newer or more complete restaurant row if needed
```

Do not return unrelated restaurant rows.

### Missing posts

If the restaurant exists but has no related posts, return:

```dart
restaurants: [matchedRestaurant]
posts: []
```

This is important because the user should still see which restaurant the search is scoped to.

---

## Do Not Do This

Do not return:

```dart
restaurants: []
```

when a matching restaurant exists.

Do not treat `restaurant` as a normal keyword token.

Do not search unrelated restaurants just because the query contains a partial name.

Do not open Google Maps from the search repository.

Do not change `RestaurantDetailScreen` query contract yet.

The current contract remains:

```text
restaurant: <restaurant-name>
```

---

## Future Improvement Note

The current query contract uses restaurant name.

A stronger future design would be ID-based:

```text
restaurant_id: <restaurant-id>
```

or a typed constructor:

```dart
SearchResultScreen.forRestaurant(
  restaurantId: restaurantId,
  restaurantName: restaurantName,
)
```

Do not implement this unless specifically requested.

For now, keep:

```text
restaurant: <restaurant-name>
```

and make it return both the matched restaurant row and related posts.

---

## Final Checks

Before finishing, verify:

- Normal search still works.
- `restaurant: Sushi Nori` returns one matched restaurant row if the restaurant exists.
- `restaurant: Sushi Nori` returns posts linked to that restaurant.
- If the restaurant exists but has no posts, the restaurant row still appears.
- If the restaurant does not exist, both restaurant and post lists are empty.
- `SearchResultScreen` All mode shows restaurant context plus related posts.
- Restaurant filter shows the matched restaurant.
- Posts filter shows related posts only.
- No raw cuisine UUID is displayed.
- No unrelated restaurant rows are returned.