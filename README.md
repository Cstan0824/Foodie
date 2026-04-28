# Foodie

Foodie is a Flutter social food app built around restaurant discovery, post sharing, saved collections, and lightweight admin moderation. The app is designed with a Cupertino-first UI and uses Supabase directly for auth, data, storage, and social interactions.

## What’s In The App

- Email/password auth, OTP verification, password reset, Google sign-in, and Apple sign-in.
- A ranked home feed with `Following` and personalized `Discover` tabs.
- Post creation with multi-image upload, captions, hashtags, restaurant tagging, and pending restaurant approval support.
- Restaurant search and post search with suggestions, trending queries, and relevance ranking.
- Collections for posts and restaurants, including sharing and cloning.
- User profiles with follow/follower relationships, liked posts, archived posts, pending restaurant approvals, and profile image upload.
- In-app notifications for likes, comments, and collection sharing.
- A Blind Box recommendation flow for restaurant discovery, plus swipe history.
- Admin surfaces for dashboard metrics, restaurant approval review, post moderation, and comment moderation.

## Tech Stack

| Layer | Implementation |
| --- | --- |
| App framework | Flutter |
| Language | Dart |
| UI style | Cupertino-first, iOS-leaning design |
| Backend | Supabase |
| Auth | Supabase Auth + OAuth |
| Database | Supabase Postgres |
| Storage | Supabase Storage |
| Local persistence | `shared_preferences` |
| Maps / location signals | `geolocator`, external map URLs |
| Deep links | `app_links` |

## Architecture

The app uses a feature-first Flutter structure with a repository-based data layer.

```text
lib/
├── main.dart
├── core/
│   ├── services/          # Supabase/account service accessors
│   ├── theme/             # AppColors and app-wide styling
│   ├── utils/             # Shared utilities like hashtags and time handling
│   └── widgets/           # Reusable Cupertino widgets and skeleton loaders
├── data/
│   ├── models/            # Strongly typed app/domain models
│   └── repositories/      # Supabase-backed data access and ranking logic
└── features/
    ├── admin/             # Admin dashboard and moderation flows
    ├── auth/              # Login, signup, OTP, reset password
    ├── collection/        # Saved posts/restaurants and shared collections
    ├── feed/              # Home feed
    ├── notification/      # Notifications inbox
    ├── post/              # Create, edit, detail, report
    ├── profile/           # Profile, edit profile, followers/following
    ├── restaurant/        # Blind Box, swipe history, restaurant details
    └── search/            # Explore and search result flows
```

## Main User Flows

### App shell

After login, regular users land in a 5-tab shell:

1. `Home`
2. `Collection`
3. `Add Post`
4. `Blind Box`
5. `Profile`

Admins are routed to a separate admin experience from the login flow.

### Feed

- `HomeScreen` supports `Following` and `Discover`.
- Discover ranking is implemented in `lib/data/repositories/feed_repository.dart`.
- Ranking uses saved preferences, location, engagement, freshness, interaction penalties, and diversity reranking.

### Search

- Search suggestions and results are implemented in `lib/data/repositories/search_repository.dart`.
- Supports restaurant-first queries, hashtag-aware search, trending searches, and multiple sort modes.

### Posting

- Post creation is handled in `lib/features/post/screens/add_post_screen.dart`.
- Posts require a title, caption, at least one image, and either an approved restaurant or a pending restaurant approval.

### Collections

- Collections support saved posts, saved restaurants, public/private metadata, sharing with followers, and cloning.
- Core logic lives in `lib/data/repositories/collection_repository.dart`.

### Admin

- Dashboard and moderation entry points live in `lib/features/admin/`.
- Restaurant approvals are managed through `lib/data/repositories/restaurant_approval_repository.dart`.
- Report handling is managed through `lib/data/repositories/report_repository.dart`.

## Local Development

### Prerequisites

- Flutter SDK
- Dart SDK compatible with `pubspec.yaml`
- Xcode for iOS builds
- CocoaPods for iOS dependency installation
- A Supabase project

### Install

```bash
flutter pub get
```

### Environment

Create `.env` in the project root:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

## Supabase Requirements

The app assumes more than just auth keys. Before running end-to-end, make sure your Supabase project has the following pieces configured.

### Database

The repository uses tables and relations referenced throughout `lib/data/repositories/`. SQL snapshots are included in the repo root:

- `schema.sql`
- `updated_schema.sql`
- `seed_data.sql`
- `schema/`
- `MOCK/`

The code also expects an RPC named `check_email_exists`, used during signup/email validation in `lib/data/repositories/auth_repository.dart`.

### Storage buckets

The current code uploads files into these Supabase Storage buckets:

- `user_images`
- `post_images`
- `restaurant_images`
- `restaurant_approval_image`

### OAuth / deep links

Google sign-in, Apple sign-in, and auth redirects use:

```text
io.supabase.tastespot://login-callback/
```

The app also handles custom deep links for profile navigation through the `io.supabase.tastespot` and `tastespot` schemes.

## Running The App

```bash
flutter run
```

iOS-first workflow:

```bash
flutter run -d ios
```

## Building

```bash
flutter build ios
flutter build apk
```

## Useful Project Files

- `lib/main.dart`: app bootstrap, Supabase init, deep links, tab shell.
- `lib/core/services/supabase_service.dart`: shared Supabase access.
- `lib/data/repositories/feed_repository.dart`: discover/following/nearby/cuisine feed logic.
- `lib/data/repositories/search_repository.dart`: search ranking and trending queries.
- `lib/data/repositories/post_repository.dart`: post CRUD, image upload, archive/block flows.
- `lib/data/repositories/profile_repository.dart`: profile reads, avatar upload, follower/following logic.
- `lib/data/repositories/blind_box_repository.dart`: recommendation and swipe history logic.

## Quality Checks

Common local checks:

```bash
dart format lib
dart analyze
flutter test
```

## Notes

- The UI is heavily Cupertino-oriented even though a small amount of Material API usage appears in isolated widgets/icons.
- Time-based “ago” formatting is normalized through `lib/core/utils/app_time.dart`.
- This is a private project and is not intended for publishing to `pub.dev`.
