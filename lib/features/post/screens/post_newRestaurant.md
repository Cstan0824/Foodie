

# Add New Restaurant During Post Creation Guideline

## Current Issue

The current add-post flow expects the user to select an existing restaurant from the database before creating a post.

However, users may want to create a post for a restaurant that is not in the database yet.

Current issue:

```text
User creates post
  → user searches restaurant
  → restaurant not found
  → user cannot continue properly
```

The add-post screen should support this missing-restaurant case by allowing users to submit a new restaurant request for admin review.

The add new post file is:

```text
lib/features/post/screens/add_post_screen.dart
```

---

## Main Goal

Add a simple “Add new restaurant” flow inside `add_post_screen.dart`.

When the user cannot find a restaurant, they should be able to submit a new restaurant through a bottom sheet form.

After submission:

```text
RestaurantApproval row is created
  → approval_Id is returned
  → add_post_screen.dart stores the approval_Id
  → the post creation form shows the restaurant as pending review
  → post creation uses restaurant_approval_id instead of restaurant_Id
  → post is created as pending
```

---

## Target User Flow

```text
User opens Add Post screen
→ user taps/selects restaurant field
→ user searches for a restaurant
→ if restaurant is not found, show “Can’t find it? Add a new restaurant”
→ user taps it
→ bottom sheet form opens
→ user fills restaurant name, main cuisine, and address
→ user submits the form
→ RestaurantApproval row is created
→ returned approval_Id is stored in Add Post screen
→ selected restaurant display shows “Pending review”
→ user completes the post
→ post is created with restaurant_approval_id and isPending = true
```

---

## Files to Focus On

```text
lib/features/post/screens/add_post_screen.dart
lib/data/repositories/post_repository.dart
lib/data/repositories/restaurant_approval_repository.dart
lib/data/repositories/restaurant_repository.dart
lib/data/models/cuisine_model.dart
```

Only update other files if compile errors require small model/repository compatibility changes.

Do not modify admin approval UI unless the repository contract requires compatibility.

---

## Bottom Sheet UX

Use a bottom sheet form, not a small alert dialog.

Reason:

```text
The form has multiple fields.
It may need to scroll on smaller screens.
It feels more natural for mobile input.
```

Suggested title:

```text
Add New Restaurant
```

Suggested helper text:

```text
Can’t find the restaurant? Submit it for admin review.
Your post will stay pending until the restaurant is approved.
```

---

## Form Fields

Keep the form simple for users.

### Required fields

```text
Restaurant name *
Main cuisine *
Address *
```

### Optional field

```text
Info URL
```

The optional info URL can be:

```text
restaurant website
social media page
Google information page
other useful verification link
```

---

## Fields to Skip for Now

Do not ask normal users for these fields in this version:

```text
rating
description
price range
restaurant images
latitude
longitude
maps URL
extra cuisine tags
```

These can be completed or corrected later by admin during the approval process.

The goal is to keep the user-facing form lightweight.

---

## Bottom Sheet Layout Suggestion

```text
Add New Restaurant

Can’t find the restaurant? Submit it for admin review.
Your post will stay pending until the restaurant is approved.

Restaurant name *
[ Sakura Sushi Bar ]

Main cuisine *
[ Select cuisine v ]

Address *
[ Full restaurant address ]

Info URL (optional)
[ Website / social / Google info link ]

[ Submit for Review ]
```

If the user typed a search query before tapping add new restaurant, prefill the restaurant name field with that query.

Example:

```text
Search query: Sakura Sushi Bar
Restaurant name field: Sakura Sushi Bar
```

---

## Where to Show “Can’t Find It?”

Inside the restaurant search/selection area in `add_post_screen.dart`, add a fallback action.

Suggested placement:

```text
Search restaurant...

[Restaurant result 1]
[Restaurant result 2]

Can’t find it?
+ Add a new restaurant
```

If no search results are found, show a stronger empty state:

```text
No restaurant found for “Sakura Sushi Bar”
+ Add “Sakura Sushi Bar” as a new restaurant
```

Suggested wording:

```text
Can’t find it? Add a new restaurant
```

or:

```text
Add new restaurant for review
```

The word “review” is useful because the restaurant should not appear public immediately.

---

## RestaurantApproval Creation

When the bottom sheet form is submitted, call `RestaurantApprovalRepository`.

Expected conceptual call:

```dart
final approvalId = await RestaurantApprovalRepository.instance.submitForApproval(
  name: restaurantName,
  mainCuisineId: selectedMainCuisineId,
  address: address,
  source: 'USER',
);
```

Use the actual method signature in `RestaurantApprovalRepository`.

The returned `approvalId` must be passed back to `add_post_screen.dart` state.

---

## Info URL Note

The desired UX includes an optional `Info URL` field.

Before wiring it, check whether `RestaurantApprovalRepository.submitForApproval()` and the `RestaurantApproval` table support an `info_url` column.

Based on the current schema shared, `RestaurantApproval` has:

```text
approval_Id
curr_restaurant_id
restaurant_name
address
latitude
longitude
maps_url
source
status
detectedAt
main_cuisine_id
rating
image_url
description
price_range
```

It does not currently show `info_url`.

So use one of these approaches:

```text
Option A: skip Info URL for now to avoid schema mismatch
Option B: store the optional URL into maps_url only if the app treats it as a map/info verification link
Option C: add info_url to RestaurantApproval later
```

Recommended for the first implementation:

```text
Keep only restaurant name, main cuisine, and address first.
Add Info URL only if the repository/schema already supports it safely.
```

---

## AddPostScreen State Required

`add_post_screen.dart` should support two restaurant selection paths.

Suggested state:

```dart
String? _selectedRestaurantId;
String? _selectedRestaurantName;
String? _restaurantApprovalId;
bool _isRestaurantPendingApproval = false;
```

---

## State Case 1: Existing Restaurant Selected

When the user selects an existing approved restaurant:

```text
_selectedRestaurantId = real Restaurant.restaurant_Id
_selectedRestaurantName = selected restaurant name
_restaurantApprovalId = null
_isRestaurantPendingApproval = false
```

The post should be created normally:

```text
restaurant_Id = selected restaurant ID
restaurant_approval_id = null
isPending = false
```

---

## State Case 2: New Restaurant Submitted

When the user submits a new restaurant from the bottom sheet:

```text
_selectedRestaurantId = null
_selectedRestaurantName = submitted restaurant name
_restaurantApprovalId = returned approval_Id
_isRestaurantPendingApproval = true
```

The post should be created as pending:

```text
restaurant_Id = null
restaurant_approval_id = returned approval_Id
isPending = true
visible_to_owner = true
```

---

## Selected Restaurant Display

After the user submits a new restaurant for review, show the selected restaurant clearly in the add-post form.

Suggested display:

```text
Sakura Sushi Bar
Pending review
```

This tells the user:

```text
The restaurant is selected for this post,
but the post will stay pending until admin approval.
```

If the user selects an existing approved restaurant, show the normal selected state:

```text
Sakura Sushi Bar
```

Do not make pending restaurants look the same as approved restaurants.

---

## PostRepository Change Required

The current `PostRepository.createPost()` forces an existing restaurant ID.

Current behavior concept:

```dart
required String restaurantId

if (restaurantId.trim().isEmpty) {
  throw Exception('A post must be tied to a restaurant.');
}
```

This must change because the app now has two valid post creation paths:

```text
existing approved restaurant
new restaurant pending approval
```

---

## New Post Creation Rule

A post must have either:

```text
restaurantId
```

or:

```text
restaurantApprovalId
```

At least one is required.

Valid cases:

| Case | restaurant_Id | restaurant_approval_id | isPending |
|---|---|---|---|
| Existing restaurant selected | real restaurant ID | null | false |
| New restaurant submitted | null | approval ID | true |

Invalid case:

| Case | restaurant_Id | restaurant_approval_id |
|---|---|---|
| No restaurant context | null | null |

---

## Suggested createPost Signature

Update `createPost()` so `restaurantId` is nullable and `restaurantApprovalId` is optional.

Conceptual signature:

```dart
Future<String> createPost({
  required String userId,
  String? restaurantId,
  String? restaurantApprovalId,
  required String title,
  required String caption,
  List<String> hashtags = const [],
  List<Uint8List> images = const [],
})
```

Use the actual existing parameters and keep current image/hashtag behavior intact.

---

## PostRepository Validation Logic

Replace strict restaurant ID validation with either/or validation.

Conceptual logic:

```dart
final hasRestaurant = restaurantId != null && restaurantId.trim().isNotEmpty;
final hasApproval = restaurantApprovalId != null &&
    restaurantApprovalId.trim().isNotEmpty;

if (!hasRestaurant && !hasApproval) {
  throw Exception(
    'A post must be tied to a restaurant or pending restaurant approval.',
  );
}
```

Optional safety rule:

```text
If both restaurantId and restaurantApprovalId are provided, prefer existing restaurant and ignore approval ID, or throw validation error.
```

Recommended:

```text
Do not allow both at the same time.
```

Conceptual check:

```dart
if (hasRestaurant && hasApproval) {
  throw Exception('Post cannot use both an approved restaurant and pending restaurant approval.');
}
```

---

## Post Insert Mapping

When creating the post, insert fields based on the selected path.

Conceptual insert:

```dart
{
  'post_Id': postId,
  'user_Id': userId,
  'restaurant_Id': hasRestaurant ? restaurantId : null,
  'restaurant_approval_id': hasApproval ? restaurantApprovalId : null,
  'title': title,
  'caption': caption,
  'isPending': hasApproval,
  'visible_to_owner': true,
  'isRemoved': false,
  'isBlocked': false,
}
```

Keep existing image upload and hashtag sync behavior unchanged.

---

## Pending Post Visibility

When a post is created with a pending restaurant approval:

```text
isPending = true
visible_to_owner = true
```

This means:

```text
The owner can still see their pending post.
Other users should not see it in public feeds until approval.
```

Make sure existing feed queries already filter out pending posts from public feeds. If not, update feed queries later.

---

## Admin Approval Flow Context

When admin approves the restaurant:

```text
RestaurantApproval accepted
→ real Restaurant row is created
→ pending posts with restaurant_approval_id are updated
→ restaurant_Id is set to the new Restaurant.restaurant_Id
→ restaurant_approval_id is cleared
→ isPending is set to false
```

When admin rejects the restaurant:

```text
RestaurantApproval rejected
→ linked pending posts should be blocked/hidden or handled according to existing approval repository behavior
```

The add-post flow only needs to create the approval and pending post correctly.

---

## Error Handling

### Bottom sheet submission errors

If restaurant approval submission fails:

```text
Show friendly error
Keep bottom sheet open
Do not create post yet
```

### Post creation errors

If post creation fails after restaurant approval was created:

```text
Show friendly error
Keep selected pending restaurant state if possible
Allow user to retry post creation
```

### Missing required fields

Validate in bottom sheet:

```text
Restaurant name is required
Main cuisine is required
Address is required
```

Do not call repository until required fields are valid.

---

## Do Not Do This

Do not insert new user-submitted restaurants directly into `Restaurant`.

Do not create a public post with `isPending = false` when using `restaurant_approval_id`.

Do not force `restaurantId` if `restaurantApprovalId` exists.

Do not allow a post to be created with neither `restaurantId` nor `restaurantApprovalId`.

Do not ask users for too many admin-level restaurant fields.

Do not make the new restaurant immediately searchable as an approved restaurant.

---

## Recommended Implementation Order

1. Inspect `add_post_screen.dart` restaurant selector/search UI.
2. Add “Can’t find it? Add a new restaurant” action.
3. Build bottom sheet form with restaurant name, main cuisine, and address.
4. Load primary cuisine options for the main cuisine selector.
5. Submit bottom sheet form through `RestaurantApprovalRepository.submitForApproval()`.
6. Store returned `approval_Id` in `add_post_screen.dart` state.
7. Show selected restaurant as “Pending review”.
8. Update `PostRepository.createPost()` to accept either `restaurantId` or `restaurantApprovalId`.
9. Update add-post submission to pass the correct values.
10. Test existing approved restaurant posting still works.
11. Test new restaurant pending post creation works.

---

## Final Checks

Before completing, verify:

- Existing restaurant selection still creates normal posts.
- Searching restaurants still works.
- Empty/no-result restaurant search shows “Can’t find it? Add a new restaurant”.
- Bottom sheet opens correctly.
- Restaurant name, main cuisine, and address are required.
- Restaurant name can be prefilled from the search query.
- Submitting bottom sheet creates a `RestaurantApproval` row.
- Returned `approval_Id` is stored in `add_post_screen.dart`.
- Add post screen shows the selected pending restaurant with “Pending review”.
- Post creation no longer forces `restaurantId` when `restaurantApprovalId` exists.
- Pending post is created with `restaurant_approval_id` and `isPending = true`.
- Approved-restaurant posts are still created with `restaurant_Id` and `isPending = false`.
- Users are clearly informed that the new restaurant/post is pending admin review.