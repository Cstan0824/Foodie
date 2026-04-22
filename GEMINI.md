# Taste Spot — AI Coding Assistant Context

This document contains the essential context for Gemini CLI (or any AI coding assistant) to understand the "Taste Spot" project, its current state, architecture, database rules, and next steps. 

## 1. Project Overview & Tech Stack
**Taste Spot** is a food & beverage community mobile app built with Flutter, heavily inspired by Xiaohongshu (小红书 / RED). Users can discover restaurants, share food-related posts ("notes"), save collections, follow other foodies, and get random restaurant recommendations via a "Blind Box" shake-to-discover feature.

- **Primary Platform:** iOS (Uses Cupertino-style widgets)
- **Framework:** Flutter (Dart SDK ^3.9.0)
- **Backend:** Supabase (PostgreSQL, Auth, Storage)
- **Key Dependencies:**
  - `supabase_flutter` & `flutter_dotenv` (for backend integration)
  - `sensors_plus` (for accelerometer / shake detection in Blind Box)
  - `appinio_swiper` (for Tinder-like cards in Blind Box)

## 2. Current Project Status
- **Status:** Early-stage UI prototype.
- **Frontend:** Most core UI screens are built (Home, Collection, Add Post, Blind Box, Profile, Search, Notifications, Auth). Navigation currently uses manual `Navigator.push()` and a custom bottom tab bar.
- **Backend Connection:** **NOT CONNECTED.** The app currently relies entirely on hardcoded, in-memory mock data. `Supabase.initialize()` is NOT called in `main.dart` yet. 
- **Database Schema:** Designed and available in `.supabase/schema.sql`, but the frontend does not read/write to it yet.

## 3. Project Structure
The app follows a feature-based folder structure:
- `lib/main.dart` - App entry point and MainShell (bottom tab bar layout).
- `lib/core/` - Theme (`app_theme.dart` for brand colors), utilities, and shared widgets.
- `lib/data/` - Data models (e.g., `post_model.dart` currently holds mock posts).
- `lib/features/` - Feature modules (`auth/`, `feed/`, `collection/`, `post/`, `profile/`, `restaurant/`, `search/`, `notification/`). Each feature has its own `screens/` directory.
- `.supabase/schema.sql` - Full PostgreSQL schema representing the current database design.

## 4. Database Architecture & Business Rules
The database has undergone multiple migrations and refactors. Here are the **active rules and schema design** that the backend integration must adhere to:

### 4.1 Restaurants & Approvals
- User-submitted restaurants go to `RestaurantApproval` first (`status`: 0=pending, 1=accepted, 2=rejected).
- An accepted approval creates a new `Restaurant` and may disable an older conflicting one (`isDisabled`).
- **Cuisines:** A restaurant has exactly ONE main cuisine (`Restaurant.main_cuisine_id`). Additional tags are added via the `Restaurant_Cuisine` many-to-many table. `Cuisine.isPrimaryOption` dictates if it can be a main cuisine.

### 4.2 Posts ("Notes")
- Every `Post` **must** be tied to a `Restaurant`. Free-floating posts are not allowed.
- Posts for unapproved restaurants are created with `isPending = true` and only become visible when the restaurant is approved.
- Important Post state flags: `isPending` (waiting approval), `isRemoved` (deleted/hidden), `isBlocked` (access restricted).

### 4.3 Collections & Saves
- The old `Saved` and `collections_post` tables are DEPRECATED.
- Use `collections` (which has a `collection_type` of `RESTAURANT` or `POST`) and `collections_item`.
- `collections_item` contains `collection_Id`, and exactly one of `restaurant_id` or `post_id` (the other must be NULL).
- Each user gets default collections for posts and restaurants (`is_default = true`).

### 4.4 Hashtags & Followers
- **Hashtags:** Normalized many-to-many design. The `hashtag` table stores master records, and `post_hashtag` links them to a `Post`. (Do not use JSON blobs).
- **Followers:** `Follower` table handles user-to-user relationships. Self-following is prevented.

### 4.5 Moderation & Notifications
- **Reports:** The `Report` table handles moderation (`status`: 0=Pending, 1=Remove, 2=Dismissed). `Comment_Report` is DEPRECATED.
- **Notifications:** `Notification` is minimal: `content`, `redirect_To`, `created_At`, `isRead`. `Notification_Settings` manages toggles.

## 5. Upcoming Tasks & Next Steps
When interacting with this codebase, prioritize these immediate tasks:
1. **Initialize Supabase:** Load `.env` using `flutter_dotenv` and configure `Supabase.initialize()` in `main.dart`.
2. **Wire up Auth:** Connect the existing login/signup UI forms to Supabase Auth and add session management / protected routing.
3. **Build Data/Repository Layer:** Create proper repository classes (e.g., in `lib/data/repositories/`) to interact with Supabase tables (Posts, Profiles, Restaurants, Collections).
4. **Data Serialization:** Add `fromJson`/`toJson` factories to existing and new data models.
5. **Real Feed & Storage:** Fetch real posts for the home feed and implement `image_picker` + Supabase Storage for creating posts.
6. **State Management:** Eventually replace local `setState` with a robust state management solution (e.g., Riverpod or Provider).
