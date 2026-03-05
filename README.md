# Taste Spot

A **food & beverage community** application built with [Flutter](https://flutter.dev), primarily targeting **iOS** while also supporting Android and other platforms.

---

## About

Taste Spot brings food and beverage enthusiasts together in one place. Discover new flavors, share your favorite spots, and connect with a community that shares your passion for great food and drinks.

## Features

- **Community-Driven** — Join a growing community of food and beverage lovers.
- **User Authentication** — Secure sign-up and login powered by [Supabase](https://supabase.com).
- **Cross-Platform** — Built with Flutter for iOS, Android, and beyond — with an **iOS-first** design approach.
- **Environment Configuration** — Managed via `flutter_dotenv` for flexible deployment.

## Tech Stack

| Layer            | Technology                |
| ---------------- | ------------------------- |
| Framework        | Flutter (Dart ^3.10.7)    |
| Backend / Auth   | Supabase                  |
| Primary Platform | iOS                       |
| Architecture     | MVC (Model-View-Controller) |

## Project Structure

This project uses a feature-based layout to keep code organized by responsibility.

```
lib/
├── main.dart               # App entry point (minimal)
├── app.dart                # CupertinoApp configuration
├── assets/                 # Icons & images
├── core/                   # App-wide utilities and theme
│   └── theme/              # Color and theme definitions (app_colors.dart)
├── data/                   # Data layer
│   ├── models/             # Data models (post_model.dart)
│   ├── mock/               # Mock data used for development
│   └── repositories/       # Data access / repositories
├── controllers/            # Business logic controllers
├── helpers/                # Small utilities (auth helpers, etc.)
├── views/                  # UI layer (feature folders)
│   ├── screens/            # Screen implementations (grouped under views/screens)
│   └── shared/             # Reusable widgets (post_card.dart)
└── pubspec.yaml

Purpose:
- `core/`: shared theme and utility functions used across the app.
- `data/`: models and repositories abstracting backend or mock data.
- `controllers/`: application logic and state management entry points.
- `views/`: feature UI code; `shared/` contains reusable widgets.
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (channel stable)
- Dart SDK ^3.10.7
- Xcode (for iOS development)
- CocoaPods (for iOS dependencies)
- A [Supabase](https://supabase.com) project with valid credentials

## Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/Cstan0824/taste_spot.git
   cd taste_spot
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure environment variables**

   Create a `.env` file in the project root with your Supabase credentials:

   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

4. **Run on iOS (primary target)**

   ```bash
   flutter run -d ios
   ```

   Or run on any connected device:

   ```bash
   flutter run
   ```

## Building for Production

```bash
# iOS
flutter build ios

# Android
flutter build apk
```

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Supabase Flutter SDK](https://supabase.com/docs/reference/dart/introduction)
- [Dart Language](https://dart.dev/)

## License

This project is private and not published to pub.dev.
