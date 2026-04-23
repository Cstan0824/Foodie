# Taste Spot UI/UX Modernization Plan

This plan outlines the architectural and visual improvements to transform the prototype into a high-fidelity, modern mobile experience.

## 1. Profile Page Refactor (Modern Architecture)
- **Navigation Header:** 
    - Move `username` (handle) to `middle` of `CupertinoNavigationBar`.
    - Place "Settings/More" and "Share" icons as trailing actions.
- **Identity Header:**
    - Centered Avatar with a refined border (2pt stroke with padding).
    - **Display Name** positioned prominently below the avatar.
    - **Stats Row**: "Posts", "Followers", "Following" metrics with a vertical layout for each item.
    - Clean Bio section with "Interest Tags" using a more subtle background color.
- **Tabs:** Refine the "Posts" and "Liked" tab bar with a thinner, more elegant indicator.

## 2. Collection Page & Modals
- **Hierarchy**: Use "Card Stacks" visuals to represent Albums so they look like physical collections.
- **Add Collection Modal**:
    - Convert `CupertinoAlertDialog` to a `CupertinoActionSheet` or a custom **Draggable Bottom Sheet**.
    - Implement a "Type Selector" that uses icons instead of a segmented control for better tap targets.
- **Detail Page**: Improve the header to show "Collection Owner" and "Privacy Status" more clearly.

## 3. Notification Page Simplification
- **Removal**: Delete the `_buildFilterBar` and the refresh icon in the navigation bar.
- **UI Focus**:
    - Focus on a single, clean chronological stream.
    - Increase avatar size slightly (from 48 to 52).
    - Use better typography to distinguish between the "Actor Name" and the "Action Text".

## 4. Satisfying Skeleton Loading
- **Shimmer Effect**: Replace static `Skeleton` boxes with an animated gradient shimmer.
- **Structural Integrity**: Create specific skeleton wrappers for `PostCard`, `CollectionCard`, and `NotificationTile` to ensure the layout is identical during loading.

## 5. Global UI/UX Refinement
- **Login/Signup**: 
    - Add "Glassmorphism" or subtle gradients to backgrounds.
    - Improve input field focus states (change border color on active).
- **Edit Profile**:
    - Use a dedicated "Change Photo" overlay on the avatar.
    - Group settings into "Account" and "Personal" sections.

## 6. Implementation Phases
1. **Phase 1**: Skeleton & Global Theming (The Foundation).
2. **Phase 2**: Profile Page Transformation.
3. **Phase 3**: Collection & Modal UX.
4. **Phase 4**: Notification & Auth Screen Polish.
