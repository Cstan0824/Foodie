# User & Authentication Module

This module handles user identity, account management, and personalized content such as collections and notifications. It is designed with a heavy emphasis on a premium iOS (Cupertino) aesthetic and smooth, interactive user experiences.

## Overview
The module provides a complete lifecycle for users, from onboarding (sign up/login) to social interaction (following/sharing) and personal organization (collections). It integrates deeply with **Supabase Auth** and **PostgreSQL** for real-time data and session management.

---

## 1. Login Page
The gateway to the Foodie experience, focusing on security and ease of access.

- **Involved Pages:** `LoginScreen`, `ForgotPasswordScreen`, `VerifyOTPScreen`.
- **Techniques Used:**
    - **Supabase Auth Integration:** Handles email/password authentication and session persistence.
    - **Social Authentication:** Native support for **Google** and **Apple** sign-in providers.
    - **Interactive UI:** Animated text field containers that respond to focus and validation errors.
    - **Stream-based Auth Listeners:** Uses `onAuthStateChange` to automatically redirect users upon successful login or session recovery.
    - **Custom Error Mapping:** Converts technical backend errors into user-friendly guidance.

## 2. Signup Page
A robust onboarding flow that ensures data integrity and user uniqueness.

- **Involved Pages:** `SignupScreen`, `CompleteProfileScreen`.
- **Techniques Used:**
    - **Real-time Validation:** Implements **debounced searching** to check for username and email availability as the user types, reducing server load.
    - **OTP Verification:** Integrated One-Time Password flow for email verification before account activation.
    - **Password Security:** Client-side validation for password strength and length.
    - **Profile Initialization:** Automatically creates a corresponding user profile in the database upon successful authentication.

## 3. Collection Page
The personal hub for organizing saved flavor discoveries.

- **Involved Pages:** `CollectionScreen`.
- **Techniques Used:**
    - **Segmented Control:** Uses `CupertinoSlidingSegmentedControl` to toggle between "My Items" and "Shared" collections.
    - **Custom Overlay Menus:** A sophisticated category filtering system (All, Restaurants, Posts) using animated overlays.
    - **Folder Stack Visuals:** A custom-built UI component that mimics a physical stack of cards to represent collection contents.
    - **Search & Filter:** Real-time filtering logic to find collections by name or type.

## 4. Collection Details Page
A deep dive into specific user-curated lists.

- **Involved Pages:** `CollectionDetailScreen`.
- **Techniques Used:**
    - **Context-Aware Layouts:** Dynamically switches between a restaurant list view and a post masonry grid based on the collection type.
    - **Collaboration Tools:** Support for sharing collections with followers and cloning public collections to a user's own library.
    - **Search within Context:** Dedicated search bar for filtering items strictly within the current collection.

## 5. Notification Page
The social heartbeat of the app, keeping users informed of interactions.

- **Involved Pages:** `NotificationScreen`.
- **Techniques Used:**
    - **Time-Based Grouping:** Automatically categorizes notifications into "Today", "Yesterday", "This Week", etc., for better readability.
    - **Smart Redirection:** A parsing system that interprets "redirect_To" strings to navigate the user directly to the relevant Post, Profile, or Collection.
    - **Rich Media Tiles:** Custom list tiles that display sender avatars overlaid with interaction type icons (heart for likes, bubble for comments).
    - **Real-time Status Updates:** Marks notifications as read upon viewing using batch database updates.

## 6. Profile Page
A comprehensive showcase of a user's culinary journey and social standing.

- **Involved Pages:** `ProfileScreen`, `EditProfileScreen`, `ConnectionsScreen`.
- **Techniques Used:**
    - **Multi-Account Management:** Support for saving multiple credentials and switching accounts seamlessly without full re-authentication.
    - **Masonry Grid Layout:** Efficiently displays user posts and liked content in a staggered grid.
    - **Deep Linking:** Generates shareable profile links that can open directly in the mobile app.
    - **Stateful Tabs:** Manages sub-content (Posts, Liked, Pending, Archived) with a custom `SliverPersistentHeader` for a sticky navigation effect.
    - **Social Logic:** Real-time follower/following count updates and follow-state toggling.
