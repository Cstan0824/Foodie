# TasteSpot: Progress & Learning Notes

Below is a summary of all the major milestones we've recently achieved, followed by detailed explanations of the key Flutter and Database concepts that we ran into. These concepts are incredibly common in production engineering and are highly worth studying!

---

## 🚀 What We Have Done (Recent Milestones)

### 1. Database & Backend Intelligence
- **Supabase Integration**: Fully wired the application to a live PostgreSQL backend.
- **Relational Joins**: Integrated complex join queries to retrieve related data efficiently (e.g., automatically pulling the author's real name for custom comments directly from the `User` table).
- **Silent Background Loading**: Bypassed loading spinners by implementing "stealth" loading mechanisms that refresh screen data silently in the background when swapping tabs.

### 2. UI & Aesthetics
- **Redesigned Bottom Sheets**: Stripped out bulky Apple default Modals. Built a modern, keyboard-aware inline Comment Bar, and a sleek horizontal "More Options" settings tray.
- **Dynamic Avatars & Timestamps**: Built logic to extract user initials for avatars programmatically and convert raw SQL timestamps into friendly `2h ago` strings.
- **Cross-Screen Visual Consistency**: Unified the `PostCard` widget to be identical across both the Home Feed and the Profile tabs, implementing a custom 2-column native masonry grid to prevent layout clipping/overflows.

---

## 🧠 Core Technical Concepts For Study

Here are the 4 most important engineering concepts we navigated. Take your time to review these, as realizing how these operate under the hood is what separates beginner Flutter devs from seniors.

### 1. The `StatefulWidget` Lifecycle Bug (Recycled UI)
**The Problem**: When you swapped from the "Notes" tab to the "Liked" tab, the images on the screen didn't change, even though tapping on them opened the correct new post!
**The Concept**: Because creating UI is expensive, Flutter tries to drastically save memory by "recycling" widgets in lists/grids. When you switched tabs, Flutter handed the old `PostCard` the new `PostModel` data. However, the `PostCard`'s `initState()` method **only ever runs once** when the widget is born. It completely ignored the new data injection.
**The Fix**: We added `didUpdateWidget()`. This is a lifecycle "alarm bell" that specifically fires when a parent attempts to hand a recycled widget new data, forcing it to overwrite its internal memory and repaint.

### 2. Local Component State vs. Global State Management
**The Problem**: Liking a post on the Home tab didn't immediately cause it to appear in the "Liked" tab on the Profile screen until you manually refreshed.
**The Concept**: Vanilla Flutter is completely localized. If you call `setState()` inside the Home Screen, the Profile screen literally doesn't know it happened. Many modern apps solve this by wrapping the entire app in a "Global State" framework (like Riverpod or React Redux), where data flows downwards automatically.
**The Fix**: Instead of rewiring the entire app architecture right now, we intercepted the `main.dart` Bottom Navigation Bar. Now, strictly tapping the "Profile" icon physically triggers a silent database request in the background, simulating instantaneous global state updates seamlessly.

### 3. PostgREST `!inner` Joins
**The Problem**: We needed a way to securely fetch *only* the posts that the logged-in user had liked. 
**The Concept**: A naive approach is to fetch all 100,000 posts in the database, bring them to the phone, and use Dart to filter through them. This would instantly crash the app. Instead, we must let the backend do the heavy lifting using relational SQL.
**The Fix**: We used `Likes!inner(user_Id)`. In Supabase, the `!inner` keyword tells PostgreSQL: *"Only return the parent Post row IF you can confirm at least one child row exists in the Likes table matching this specific user Id."* This accomplishes the goal in roughly ~2 milliseconds.

### 4. iOS Safe Area Propagation Quirks (The Giant Gap Bug)
**The Problem**: When tagging a restaurant, a massive empty space appeared between the search bar and the list of restaurants inside the modal.
**The Concept**: All iPhones have a notch or a "Dynamic Island" at the top of the physical screen. To prevent scrolling lists from colliding with the physical notch, Flutter natively injects a massive chunk of invisible padding into the top of every `ListView`.
**The Fix**: Because our `ListView` was trapped inside a mini Bottom Sheet—and not sitting at the top of the physical screen—that automatic notch-padding created a massive ghost gap. We simply overrode the list with `padding: EdgeInsets.zero` to explicitly strip the phone's safe-area assumptions!

---

## 🧠 Extended Concepts (Session 2)

Here are additional concepts we covered in our second session of learning!

### 5. Method Chaining vs Await-Separated Calls
**The Problem**: After fixing the `comment_Id` bug, comments were inserting correctly into Supabase but the new comment still wasn't appearing in the UI, forcing the user to manually refresh the page.
**The Concept**: In the old code, we were using `.insert(...).select(...)` — chained together by dots. Even though the code looks sequential, Dart packages both instructions into **one single HTTP request envelope** and sends it to Supabase together. Supabase cannot perform a complex relational JOIN (pulling the User's name) simultaneously on a row that is still being written. This caused a silent backend crash. Because the `_submitComment()` function in Dart had a silent `catch` block, it simply swallowed the error and never updated the UI.
**The Fix**: We physically broke the chain into two separate `await` statements. `await insert(...)` sends the first envelope and literally freezes the app until Supabase confirms the row was safely saved. Only then is the second envelope, `await select(...)`, allowed to depart. This guarantees the database row fully exists before we try to join it with the User table.

### 6. UUID: Client-Side vs Server-Side Generation
**The Concept**: PostgreSQL (Supabase) can automatically generate a UUID Primary Key using the built-in `gen_random_uuid()` function the instant a row is inserted. You simply don't include the ID field in your insert.
**Why We Generate in Dart**: We chose to generate the UUID in Dart first, *before* sending it to the database. This is because we needed to know the exact `comment_Id` immediately after inserting so we could fire the second `select` query. If we had let the database auto-generate the ID, we would have no way to reference that specific row in the follow-up `select` call without an extra round-trip just to retrieve it.
**The Alternative (Equally Valid)**: You can set `DEFAULT gen_random_uuid()` on the table column in Supabase, then use `.insert({...}).select('comment_Id')` to retrieve the auto-generated ID in one shot. This removes the Dart UUID generator entirely.

### 7. Database Views: Pros vs Cons
**What it is**: A View is a "Saved Query" stored inside your database. Instead of your Flutter app manually stitching multiple tables together every time, you pre-stitch them on the Supabase backend and expose the View as a virtual flat table.
**Pros**:
- **Hot-Swappable**: You can add new columns to the virtual table without rebuilding or redeploying the app.
- **Cleaner Dart Code**: The Flutter `.select()` call shrinks to one line: `.from('discover_feed_view').select()`.
- **Performance**: Views are pre-compiled. Postgres executes them faster than rebuilding the plan on each request.
- **Security**: Hides your raw table structure from front-end code.

**Cons**:
- **Harder to Prototype**: Any change to a View requires writing raw SQL in the Supabase dashboard. You lose VSCode iteration speed.
- **Visibility Loss**: New developers reading the Dart code see no clue about which tables the data is actually coming from.
- **Read-Only**: You still need direct table inserts/updates for any write operations.
- **1-to-Many Relationship Hell**: Supabase's PostgREST SDK automatically nests `Post_Image` rows as a list under each Post. A raw SQL View would require `json_agg()` grouping functions to replicate this, which is messy.
