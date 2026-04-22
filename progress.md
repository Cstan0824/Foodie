# Taste Spot — Project Progress Report

> **Last Updated:** 2026-04-20  
> **Status:** Early-stage — UI prototype with hardcoded mock data. No backend integration yet.

---

## 1. What Is This Project?

**Taste Spot** is a **food & beverage community mobile app** built with **Flutter** (Dart), heavily inspired by the **Xiaohongshu (小红书 / RED)** social platform. Users can discover restaurants, share food-related posts ("notes"), save collections, follow other foodies, and get random restaurant recommendations via a "Blind Box" shake-to-discover feature.

- **Primary Platform:** iOS (Cupertino-style widgets throughout)
- **Architecture:** Feature-based folder structure (loosely MVC)
- **Backend:** Supabase (PostgreSQL + Auth + Storage) — **configured but NOT connected**

---

## 2. Tech Stack

| Layer | Technology | Status |
|---|---|---|
| Framework | Flutter (Dart SDK ^3.9.0) | ✅ Set up |
| UI Toolkit | Cupertino (iOS-native look) | ✅ Used throughout |
| Backend | Supabase (PostgreSQL, Auth, Storage) | ⚠️ Schema designed, NOT integrated |
| Environment | `flutter_dotenv` for `.env` config | ✅ Set up |
| Sensor Features | `sensors_plus` (accelerometer for shake) | ✅ Used in Blind Box |
| Card Swiping | `appinio_swiper` (Tinder-like cards) | ✅ Used in Blind Box |

### Key Dependencies (`pubspec.yaml`)
- `supabase_flutter: ^2.5.0` — listed but **never initialized** (`main.dart` does not call `Supabase.initialize()`)
- `flutter_dotenv: ^5.1.0` — listed but not loaded at app start
- `sensors_plus: ^7.0.0` — used for shake detection in Blind Box
- `appinio_swiper: ^2.1.1` — used for restaurant card swiping

---

## 3. Project Structure

```
lib/
├── main.dart                        # App entry + MainShell (bottom tab bar)
├── assets/
│   ├── icons/                       # (empty — no custom icons yet)
│   └── images/                      # (empty — no local images yet)
├── core/
│   ├── theme/
│   │   └── app_theme.dart           # AppColors — brand color palette
│   ├── utils/
│   │   └── auth.dart                # (empty file — placeholder)
│   └── widgets/
│       └── post_card.dart           # Reusable PostCard widget (used in feed)
├── data/
│   └── models/
│       └── post_model.dart          # PostModel class + 10 hardcoded mock posts
├── features/
│   ├── auth/screens/
│   │   ├── login_screen.dart        # Login page
│   │   ├── signup_screen.dart       # Sign-up page
│   │   └── forgot_password_screen.dart  # Password reset page
│   ├── feed/screens/
│   │   └── home_screen.dart         # Home feed (masonry grid layout)
│   ├── collection/screens/
│   │   └── collection_screen.dart   # Saved posts / albums
│   ├── post/screens/
│   │   ├── add_post_screen.dart     # Create new post form
│   │   └── post_detail_screen.dart  # Full post view + comments
│   ├── profile/screens/
│   │   ├── profile_screen.dart      # User profile page
│   │   ├── edit_profile_screen.dart # Edit profile form
│   │   └── connections_screen.dart  # Following / Fans lists
│   ├── restaurant/screens/
│   │   ├── blind_box_screen.dart    # Shake-to-discover restaurant cards
│   │   └── restaurant_detail_screen.dart  # Restaurant detail page
│   ├── search/screens/
│   │   └── explore_screen.dart      # Search + trending topics
│   └── notification/screens/
│       └── notification_screen.dart # Notification feed
.supabase/
├── schema.sql                       # Full PostgreSQL schema (8 table groups)
└── mock.sql                         # (empty — no seed data)
```

---

## 4. Database Schema (Designed but NOT Connected)

A comprehensive Supabase PostgreSQL schema exists in `.supabase/schema.sql` with **8 table groups**:

| Table Group | Tables | Purpose |
|---|---|---|
| **Profiles** | `profiles`, `user_image` | User accounts linked to Supabase Auth |
| **Restaurant** | `restaurant`, `restaurant_approval` | Restaurant listings + moderation queue |
| **Post** | `post`, `post_image` | User-created food notes/reviews |
| **Comments** | `comment`, `reply` | Nested comment threads on posts |
| **Likes** | `likes` | Post like junction table |
| **Saved** | `saved` | Post save junction table |
| **Follower** | `follower` | Follow/following relationships |
| **Collections** | `collections`, `collections_post`, `collections_shares` | Saved post albums, shareable with others |
| **Notification** | `notification` | In-app notifications with redirect |

> ⚠️ **This schema has NOT been applied to any Supabase project. The app does not read from or write to any database.**

---

## 5. What's IMPLEMENTED ✅

Everything below works as a **UI-only prototype** with hardcoded, in-memory mock data. No data persists between sessions. No real authentication occurs.

### 5.1 App Shell & Navigation
- [x] `CupertinoApp` configured with custom theme (brand red `#FF2442`)
- [x] Custom bottom tab bar with 5 items: **Home**, **Collection**, **Add Post** (opens modal), **Blind Box**, **Profile**
- [x] `IndexedStack` preserves tab state across switches
- [x] Gradient "+" button in the center of the tab bar

### 5.2 Authentication Screens (UI Only)
- [x] **Login Screen** — email/password fields, "Agree to Terms" checkbox, social login buttons (Apple, Email), "Forgot Password" link, "Sign Up" link
- [x] **Sign-up Screen** — username/email/password fields, terms checkbox, navigation back to login
- [x] **Forgot Password Screen** — email input, sends mock "success" message
- [x] Both Login and Signup **bypass auth** and navigate directly to `MainShell`
- [ ] ❌ No Supabase Auth integration — `// TODO: Implement actual login via Supabase`
- [ ] ❌ No form validation (empty fields accepted)
- [ ] ❌ No social login (Apple/Google) — buttons are no-ops

### 5.3 Home Feed
- [x] Top navigation bar with **Following / Discover / Nearby** tabs (animated underline indicator)
- [x] Bell icon → navigates to Notification screen
- [x] Search icon → navigates to Explore screen
- [x] **2-column masonry grid** of post cards using mock data (10 hardcoded `PostModel` entries)
- [x] Post cards show: image (from URL), title, author avatar, author name, like count, tap-to-like toggle
- [x] Tapping a card → navigates to Post Detail screen
- [ ] ❌ Following/Discover/Nearby tabs don't filter content — all show the same mock posts
- [ ] ❌ No pagination / infinite scroll
- [ ] ❌ No pull-to-refresh

### 5.4 Post Detail Screen
- [x] Author header with avatar, name, subtitle, **Follow/Following** toggle button, "more options" (⋯) menu
- [x] Image carousel with **PageView** (3 mock images per post), dot indicators, image counter badge
- [x] Post caption with full text display (hardcoded placeholder caption)
- [x] Restaurant location tag (tappable, links to restaurant name)
- [x] Timestamp + location display
- [x] **Comments section** — 5 hardcoded mock comments with avatar, username, text, time, like count, reply button
- [x] Bottom action bar: comment input trigger, **Like** toggle, **Save/Bookmark** toggle, **Share** button
- [x] "Add Comment" bottom sheet modal with text input + "Post Comment" button
- [x] "More Options" action sheet: Save Post, Share Post, Copy Link, Report
- [ ] ❌ All interactions are local state only (likes, saves, follows reset on navigation)
- [ ] ❌ Comments are hardcoded; no real posting
- [ ] ❌ Share functionality does nothing

### 5.5 Add Post ("New Note") Screen
- [x] Full-screen modal with close (✕) and "Publish" button
- [x] Horizontal image picker carousel — tap to add mock random images, ✕ to remove
- [x] Title input field with placeholder
- [x] Description/body text field (multi-line)
- [x] Location picker row (mock: sets "Pavilion Kuala Lumpur" on tap)
- [x] Topic/tag selector row (mock: shows `# Foodie`)
- [ ] ❌ No real image picker (uses random `picsum.photos` URLs)
- [ ] ❌ Publish does nothing — just closes the modal, no data saved
- [ ] ❌ No location API / address search
- [ ] ❌ No tag/topic selection UI

### 5.6 Collection Screen
- [x] **Segmented control** tabs: "Albums" / "All Saved"
- [x] **Albums tab**: 2-column grid of 4 hardcoded album cards with cover images, titles, item counts, private lock badges
- [x] **All Saved tab**: 3-column image grid (6 Unsplash URLs cycled across 20 cells)
- [ ] ❌ No real saved post data — everything is hardcoded
- [ ] ❌ Tapping albums/images does nothing
- [ ] ❌ "+" button in nav bar does nothing (no album creation)

### 5.7 Profile Screen
- [x] Profile section: avatar (gradient ring border), display name, XHS-style user ID, stats row (**Following / Fans / Notes** with tappable counters), bio text, interest tags
- [x] **Edit Profile** button → navigates to Edit Profile screen
- [x] Tab bar: "Notes" / "Liked" — with animated underline, pinned on scroll
- [x] 2-column card grid showing mock posts (tappable → Post Detail)
- [x] Share icon in top bar (no-op)
- [x] **Logout** button → shows confirmation action sheet → navigates back to Login
- [ ] ❌ All profile data is hardcoded constants (name, bio, avatar, counts)
- [ ] ❌ Logout does not call Supabase sign-out

### 5.8 Edit Profile Screen
- [x] Change Photo button (no-op, displays avatar from URL)
- [x] Name text field (pre-filled with mock data)
- [x] Bio text field (multi-line, pre-filled)
- [x] "Save" button (just pops the screen, doesn't persist changes)
- [ ] ❌ No image upload
- [ ] ❌ No data saved to backend

### 5.9 Connections Screen (Following / Fans)
- [x] Custom nav bar with **Following / Fans** tabs + animated underline
- [x] Swipeable **PageView** between tabs
- [x] User rows: avatar placeholder, name, handle, bio, **Follow/Following** toggle
- [x] 3 mock "following" users, 4 mock "follower" users
- [ ] ❌ All data is hardcoded
- [ ] ❌ Follow/unfollow actions are local only

### 5.10 Blind Box (Shake-to-Discover)
- [x] **Three-phase UI**: Shake Prompt → Finding Animation → Card Stack
- [x] Accelerometer shake detection via `sensors_plus` (threshold `30.0`)
- [x] Fallback "Tap to Discover" button for Simulator testing
- [x] **Tinder-like swipeable restaurant cards** using `appinio_swiper` with looping
- [x] Restaurant cards show: full-bleed background image, rating badge, distance badge, name, cuisine type, price tier
- [x] **Multi-image browsing**: tap left/right of card to cycle through images (Instagram Stories-style indicators)
- [x] Tap center of card → navigates to Restaurant Detail screen
- [x] Reset button to return to shake prompt
- [x] 5 hardcoded mock restaurants with images, menus, ratings, locations
- [ ] ❌ No real location/GPS integration
- [ ] ❌ No real restaurant data source

### 5.11 Restaurant Detail Screen
- [x] Hero image transition from Blind Box card
- [x] Rating badge, distance badge, name, cuisine + price
- [x] "About this place" section (auto-generated description)
- [x] Popular Menu Items list (from mock data)
- [x] Location section with distance + Google Maps URL link
- [x] "Get Directions" button (no-op)
- [ ] ❌ No real map integration / URL launcher
- [ ] ❌ Images don't carousel (only shows initial image)

### 5.12 Search / Explore Screen
- [x] **Auto-focusing search bar** with placeholder text
- [x] **Search history** as chips (4 hardcoded entries) with clear-all trash icon
- [x] **Trending Searches** list (8 items) with colored ranking numbers (🔴🟠🟡) and "HOT" badges
- [x] Tapping a history chip or trending item fills the search field
- [x] When typing, shows mock search results (4 list tiles with generic text)
- [ ] ❌ No real search logic — results are fake placeholders
- [ ] ❌ No search API calls

### 5.13 Notification Screen
- [x] Push-style notification list: like, comment, follow, system notifications
- [x] Each notification: avatar + type badge (heart/chat/person), rich text (bold name + action), timestamp, post thumbnail or "Follow" button
- [x] Unread notifications have subtle pink background tint
- [x] Empty state UI with bell-slash icon and message
- [x] 5 hardcoded mock notifications
- [ ] ❌ No real notification system
- [ ] ❌ Not tappable / no navigation on tap

### 5.14 Theming / Design System
- [x] `AppColors` class — brand primary (`#FF2442`), accent orange, background, card, text colors, dividers, surfaces
- [x] Consistent iOS-native styling with Cupertino widgets
- [ ] ❌ No dark mode support
- [ ] ❌ No custom fonts (uses system defaults)

---

## 6. What's NOT Implemented ❌

### 6.1 Backend & Data Layer (Critical)
| Item | Notes |
|---|---|
| Supabase initialization | `Supabase.initialize()` never called in `main.dart`; `.env` not loaded |
| Authentication (Login/Signup) | Forms exist but submit handlers are stubs — no Supabase Auth calls |
| Social Auth (Apple/Google) | Buttons rendered but are no-ops |
| Password reset | Shows mock success message; no Supabase `resetPasswordForEmail()` |
| Session management | No auth state listener, no token refresh, no protected routes |
| Data models for API | `PostModel` exists but has no `fromJson()`/`toJson()` or Supabase query methods |
| Repository layer | `data/repositories/` not created — no data access classes |
| Controller layer | `controllers/` not created — no business logic separation |
| `.env` loading | `flutter_dotenv` package added but `dotenv.load()` not called |
| Mock SQL seeding | `.supabase/mock.sql` is empty |

### 6.2 Core Features Missing
| Feature | Status |
|---|---|
| Real post CRUD | No create/read/update/delete operations on posts |
| Image upload | No camera/gallery picker, no Supabase Storage upload |
| Real-time feed | No data fetching; feed shows hardcoded `mockPosts` |
| Following/Discover/Nearby filtering | Tab headers exist but all render the same content |
| Like/Save persistence | Toggle state is local `setState` only; resets on navigation |
| Comment posting | Comment sheet exists but submitted text goes nowhere |
| Follow/Unfollow persistence | Toggle works visually but nothing is saved |
| Profile data loading | All profile fields are `static const` strings |
| Profile editing persistence | Text fields pre-filled with mock data; "Save" just pops the screen |
| Collection/Album CRUD | Albums are hardcoded maps; no creation/deletion |
| Saving posts to collections | Bookmark toggle is local; no album assignment UI |
| Search with real results | Search field exists but results are generic placeholders |
| Notifications from server | Hardcoded list; no real-time push or polling |
| Restaurant data from API | Blind Box uses 5 hardcoded restaurant maps |
| GPS / Location services | No location permission request, no GPS coordinate usage |
| Map integration | Google Maps URLs shown as text; no in-app map view |
| Deep linking / URL launching | `url_launcher` not in dependencies |
| Image caching | No `cached_network_image`; images re-download on every visit |
| Error handling | Minimal — network image `errorBuilder` exists but no API error handling |
| Loading states | Only activity indicator in Blind Box's "Finding..." phase |

### 6.3 Testing
| Item | Status |
|---|---|
| Widget tests | Only the default Flutter counter smoke test (will fail — app isn't a counter) |
| Unit tests | None |
| Integration tests | None |

### 6.4 Assets
| Item | Status |
|---|---|
| App icon | Not customized (default Flutter icon) |
| Splash screen | Not customized |
| Local images/icons | `assets/icons/` and `assets/images/` folders are empty |
| Custom fonts | Not added |

---

## 7. Known Gaps & Technical Debt

1. **`auth.dart` is empty** — `lib/core/utils/auth.dart` is a 0-byte placeholder file.
2. **Widget test is stale** — `test/widget_test.dart` tests a counter app that doesn't exist; will fail if run.
3. **No state management** — entire app relies on `StatefulWidget` + `setState`. As features grow, this will need a solution (e.g., Riverpod, Provider, BLoC).
4. **No routing system** — navigation uses manual `Navigator.push()` everywhere. Consider `go_router` for declarative routing + deep links.
5. **All images are remote URLs** — no local fallback assets; app needs internet to display anything.
6. **No data serialization** — `PostModel` has no JSON factory methods. Will need `fromJson`/`toJson` for API integration.
7. **Hardcoded strings everywhere** — no internationalization (i18n) support.
8. **No environment-based config** — Despite `.env.example` existing, dotenv is never loaded.

---

## 8. Recommended Next Steps (Priority Order)

1. **🔴 Initialize Supabase** — Load `.env`, call `Supabase.initialize()` in `main.dart`
2. **🔴 Wire up Auth** — Connect login/signup forms to Supabase Auth; add session listener + protected routing
3. **🔴 Build Repository Layer** — Create `data/repositories/` classes for posts, profiles, restaurants, collections
4. **🟠 Add JSON serialization** — Add `fromJson`/`toJson` to `PostModel` and create remaining models
5. **🟠 Implement real feed** — Fetch posts from Supabase, display in home feed with pagination
6. **🟠 Image picker + upload** — Integrate `image_picker` + Supabase Storage for post creation
7. **🟡 Persist likes/saves/follows** — Write to junction tables via Supabase
8. **🟡 Real search** — Implement Supabase full-text search or filter queries
9. **🟡 State management** — Adopt Provider/Riverpod for scalable state
10. **⚪ Polish** — Dark mode, custom fonts, app icon, caching, error handling, tests

---

## 9. How to Run

```bash
# 1. Install dependencies
flutter pub get

# 2. Create .env from the example
cp .env.example .env
# Fill in your Supabase credentials

# 3. Run on iOS Simulator (primary target)
flutter run -d ios

# 4. Or any connected device
flutter run
```

> **Note:** The app will run fine without valid Supabase credentials since no backend calls are made. All data is mocked.
