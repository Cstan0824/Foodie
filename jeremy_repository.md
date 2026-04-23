# Taste Spot — Jeremy's Repository Implementations

This document summarizes the repository layer files implemented for the assigned modules: Restaurant Automation/Approval, Admin Restaurant CRUD, Search, BlindBox, and Home Feed.

These repositories sit between the UI/Screen layer and Supabase, encapsulating business logic, queries, and data mapping. They rely on the existing `SupabaseService` for the database client and use the existing data models.

## 1. Restaurant Approval Repository
**File:** `lib/data/repositories/restaurant_approval_repository.dart`

**Purpose:** Handles the workflow for users submitting new restaurants and admins reviewing them. It acts as the staging area before a restaurant officially enters the `Restaurant` table.

**Methods:**
* `fetchPendingApprovals()`: Retrieves all unreviewed submissions (`status = 0`).
* `fetchApprovalById(String approvalId)`: Gets details of a specific submission.
* `fetchApprovalHistory({int? statusFilter})`: Retrieves past reviews (accepted or rejected).
* `acceptApproval(String approvalId)`: **Admin action.** Validates the approval, inserts a new `Restaurant` record, optionally disables an old restaurant (if this is a replacement), and marks the approval as accepted (`status = 1`). Returns the new `restaurant_Id`.
* `rejectApproval(String approvalId)`: **Admin action.** Marks the approval as rejected (`status = 2`).
* `submitForApproval(...)`: **User action.** Inserts a new submission into the approval queue with `status = 0`. Returns the `approval_Id`.

## 2. Admin Restaurant Repository (Integrated)
**File:** `lib/data/repositories/restaurant_repository.dart` (Appended to existing file)

**Purpose:** Adds Admin CRUD capabilities and Cuisine management to the existing user-facing `RestaurantRepository`. It was integrated here to keep all restaurant-centric data access in one place while maintaining separate methods for admin vs. user views.

**New Methods Added:**
* **Admin CRUD:**
  * `fetchAllRestaurants({String? searchQuery, bool? isDisabled})`: Fetches restaurants for admin dashboards, including disabled ones.
  * `fetchRestaurantById(String restaurantId)`: Fetches a single restaurant, regardless of its disabled state.
  * `createRestaurant(...)`: Direct admin creation, bypassing the approval queue.
  * `updateRestaurant(...)`: Partial updates to restaurant details.
  * `setDisabled(String restaurantId, bool disabled)`: Toggles the visibility of a restaurant.
* **Cuisine Lookup:**
  * `fetchAllCuisines()`: Retrieves all cuisine types for admin dropdowns.
  * `fetchPrimaryCuisines()`: Retrieves cuisines marked as `isPrimaryOption` for user submission forms.
* **Cuisine Tags (Restaurant_Cuisine junction):**
  * `fetchRestaurantCuisineTags(String restaurantId)`: Fetches extra assigned tags.
  * `updateCuisineTags(String restaurantId, List<String> cuisineIds)`: Replaces all extra tags for a restaurant using a delete-and-insert strategy.

## 3. Search Repository
**File:** `lib/data/repositories/search_repository.dart`

**Purpose:** Orchestrates rule-based, keyword search across posts, restaurants, cuisines, and hashtags.

**Methods:**
* `searchPosts(String query)`: Matches keywords against post `title` and `caption`.
* `searchPostsByRestaurant(String query)`: Finds restaurants by name or address, then returns visible posts linked to them.
* `searchPostsByCuisine(String cuisineId)`: Returns posts linked to restaurants that have the specified cuisine (either as main or an extra tag).
* `searchPostsByHashtag(String hashtag)`: Uses a partial match on the hashtag name to find linked posts.
* `searchAll(String query)`: Performs a combined text and restaurant search in parallel, deduplicates the results, and ranks them by a calculated relevance score (engagement + freshness).
* `fetchTrendingHashtags({int limit})`: Counts recent `post_hashtag` insertions client-side to determine the top N trending hashtags.

## 4. BlindBox Repository
**File:** `lib/data/repositories/blind_box_repository.dart`

**Purpose:** Manages the system-driven restaurant recommendation engine (BlindBox), tracks swipe history to prevent repeats, and handles saving discovered restaurants.

**Methods:**
* `fetchRecommendations(...)`: Retrieves active restaurants, explicitly excluding those the user has already swiped on. Optionally filters by cuisine and shuffles the results for variety.
* `recordSwipe(String userId, String restaurantId)`: Logs an interaction in `swipe_history`.
* `fetchSwipeHistory(String userId)`: Retrieves the user's past swipes.
* `clearSwipeHistory(String userId)`: Deletes the user's swipe history, resetting recommendations.
* `saveRestaurantToCollection(String userId, String restaurantId)`: Saves a restaurant to the user's default `RESTAURANT` collection (auto-creating the collection if it doesn't exist).
* `isRestaurantSaved(...)`: Checks if the restaurant exists in any of the user's restaurant collections.

## 5. Feed Repository
**File:** `lib/data/repositories/feed_repository.dart`

**Purpose:** Provides advanced, ranked feeds based on rules (engagement and freshness) rather than simple chronological order. Separates feed logic from basic Post CRUD.

**Methods:**
* `fetchDiscoverFeed()`: Fetches a larger pool of posts and sorts them client-side based on a calculated `_relevanceScore` (likes + saves*2 + time-decay).
* `fetchFollowingFeed(String userId)`: Fetches posts exclusively from users the current user follows, then applies the relevance ranking.
* `fetchNearbyFeed(...)`: Uses a bounding-box approximation (1° ≈ 111km) to find nearby restaurants based on latitude/longitude, then returns their linked posts.
* `fetchFeedByCuisine(String cuisineId)`: Fetches posts from restaurants matching a specific cuisine (main or tag) and ranks them.
