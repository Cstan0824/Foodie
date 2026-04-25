# Search Suggestions Design Plan

## Goal
Design the search suggestion experience for Taste Spot.

This document defines:
- what should happen when the user types in the search bar
- how suggestions should be loaded
- what kinds of suggestions should be shown
- how the suggestion list should be ranked
- what UX states should exist
- what repository/data flow should support it

This document is focused on the **typed suggestion experience inside ExploreScreen**.
It is not the same as the full Search Result page.

---

# Product Intent

The current placeholder behavior such as:
- `sushi 1`
- `sushi 2`
- `sushi 3`

is not useful.

Taste Spot should show **real, database-backed suggestions** when the user types.

The goal of suggestions is to help the user:
- quickly pick a likely restaurant/entity
- quickly continue a common food/place query
- quickly choose a strong matching post-title query
- submit a search with less typing

Suggestions should feel:
- fast
- lightweight
- helpful
- relevant

Suggestions do **not** need to show the full final search-result experience.
They are only a compact assistive list shown while typing.

---

# High-Level Suggestion Flow

## User interaction flow
1. user opens `ExploreScreen`
2. search bar is focused
3. user starts typing
4. after a small pause, the app queries the database
5. real suggestions appear below the search bar
6. user can tap one suggestion
7. tapped suggestion populates the search and submits it
8. app navigates to `SearchResultScreen`

## Important behavior
Suggestions should not query the database on every single keystroke instantly.
There should be a **small debounce delay** first.

---

# Recommended Suggestion Trigger Behavior

## Empty query
If the search bar is empty:
- do NOT show typed suggestions
- show the normal ExploreScreen content instead:
  - search history
  - trending searches

## Very short query
If query is too short:
- do not query the database yet
- continue showing the normal ExploreScreen content or a minimal idle state

## Recommended threshold
Start querying suggestions when:
- query length is at least **2 characters**

Reason:
- 1-character queries are usually too noisy
- 2 characters already helps for cases like:
  - `kl`
  - `pj`
  - `su`

## Debounce delay
Use a debounce delay before querying suggestions.

### Recommended value
- **300ms**

Reason:
- fast enough to feel responsive
- slow enough to avoid spamming the database on every keystroke

## Final trigger logic
When user types:
1. cancel previous debounce timer
2. if trimmed query length < 2:
   - clear typed suggestions
   - do not query
3. otherwise wait 300ms
4. if query is still the current one after the pause:
   - fetch suggestions from repository
   - render suggestion list

---

# Suggestion Types

Suggestions should not be just one generic type.

Taste Spot should support a **mixed suggestion list**.

## Suggestion Type 1 — Restaurant suggestions
These are direct restaurant/entity suggestions.

Examples:
- `Sushi Zanmai`
- `Sushi King`
- `Sushi Kitchen`

### Purpose
Help the user quickly choose a likely restaurant match.

### Source fields
First version should use:
- `Restaurant.restaurant_name`
- `Restaurant.address` as a secondary matching signal if needed

---

## Suggestion Type 2 — Post title suggestions
These are strong post-title based suggestions.

Examples:
- `Best sushi in KL`
- `Affordable omakase in PJ`
- `Late night ramen spots`

### Purpose
Help the user quickly continue into a likely content-driven search.

### Source fields
First version should use:
- `Post.title`

Optional later:
- `Post.caption`

---

## Suggestion Type 2B — Hashtag suggestions
These are quick hashtag-based query suggestions.

Examples:
- `#sushi`
- `#ramen`
- `#omakase`

### Purpose
Help the user quickly search posts by hashtag when they are thinking in topic/tag form rather than full restaurant or sentence form.

### Behavior
When the user types a normal query such as:
- `sushi`
- `ramen`
- `dessert`

Taste Spot may offer a hashtag suggestion by simply prefixing the normalized query with `#`.

Examples:
- input: `sushi` -> hashtag suggestion: `#sushi`
- input: `ramen` -> hashtag suggestion: `#ramen`

This suggestion is not necessarily pulled from a separate hashtag table in the first version.
It can be generated from the typed query itself.

### First-version recommendation
For the first version, it is acceptable to always include one hashtag suggestion when the typed query is non-empty and meaningful.

This hashtag suggestion should appear as one of the compact suggestion rows, not as a special separate UI block.

---

## Suggestion Type 3 — Place/address driven suggestions
This is optional for later.

Examples:
- `Sushi in Setapak`
- `Cafe in Mont Kiara`

For the first version, this can be postponed.
If implemented later, it can be derived from:
- restaurant address matches
- normalized area names

---

# First-Version Recommendation

For the first version, implement:
- restaurant suggestions
- post title suggestions
- one generated hashtag suggestion

This is already enough to make the typed experience useful.

That means:
- no fake numbered suggestions
- no complicated NLP extraction
- no heavy inference logic

Just real data-backed suggestions from the database, plus one lightweight generated hashtag suggestion.

---

# Suggested UI Structure

## ExploreScreen while typing
When the user types and suggestions are available, show a compact suggestion list.

### Recommended layout
```text
<Search bar>
<suggestion list>
```

### Suggestion row style
Each row should be compact and tappable.

Suggested row contents:
- left icon indicating type
- main suggestion text
- optional small secondary text if useful later

Examples:
- restaurant icon + `Sushi Zanmai`
- post/search icon + `Best sushi in KL`

---

# Recommended Suggestion List Grouping

There are two acceptable approaches.

## Option A — One mixed list with icons
Show one combined list, but distinguish row type using icons.

Example order:
- restaurant suggestion
- restaurant suggestion
- restaurant suggestion
- post title suggestion
- post title suggestion

### Pros
- simple
- compact
- easy to build

## Option B — Small labeled sections
Show:
- `Restaurants`
- `Posts`

under the search bar.

### Pros
- clearer separation

### Cons
- visually heavier
- may be overkill for quick suggestions

## Recommended choice
Use **Option A** for the first version:
- one mixed list
- icons indicate type

This keeps the UI simple and fast.

---

# Suggested Suggestion Count

Do not show too many items.

## Recommended maximum
Show about:
- **6 suggestions total**

### Recommended distribution
- up to 2 or 3 restaurant suggestions
- up to 2 or 3 post title suggestions
- up to 1 hashtag suggestion

This is enough to feel helpful without making the list too long.

---

# Suggestion Ranking Rules

Suggestion ranking should be LIGHTER than full search ranking.

The suggestion system is only meant to provide quick assistive choices.

---

## Restaurant suggestion ranking
Rank restaurant suggestions by:

### 1. Exact / exact-ish restaurant name match
Examples:
- query = `sushi zanmai`
- restaurant = `Sushi Zanmai`
- restaurant = `Sushi Zanmai Setapak`

### 2. Strong partial restaurant name match
Examples:
- query = `zanmai`
- query = `sushi zan`
- query = `town coffee`
- restaurant = `Old Town White Coffee`

### 3. Strong address/place match
Examples:
- query = `setapak`
- restaurant address contains `Setapak`

### 4. Fuzzy restaurant fallback
Examples:
- `sushi zanmi`
- `setapka`

Fuzzy should remain lower priority than direct name/address matches.

---

## Post title suggestion ranking
Rank post title suggestions by:

### 1. Exact phrase in title
Examples:
- query = `best sushi`
- title contains `Best Sushi`

### 2. Strong partial title match
Examples:
- token overlap in the title is strong

### 3. Engagement tie-breaker
If title similarity is similar, use a light engagement boost:
- likes
- saves

### 4. Freshness tie-breaker
If still similar, prefer newer posts.

This ranking is intentionally simpler than the full search result ranking.

---

# Suggested Backend Data Flow

Do NOT use the full heavy search query on every keystroke.

Instead, implement a dedicated lightweight repository method for typed suggestions.

In addition, hashtag suggestion does not need a heavy repository query in the first version.
It can be generated cheaply from the user’s typed query.

## Recommended repository method
Something like:
- `fetchSearchSuggestions(String query)`

This method should:
- normalize the query
- reject very short queries
- query a small candidate set only
- rank lightweight suggestions
- return compact suggestion models

---

# Recommended Suggestion Model

Use a lightweight model for suggestions.

Example conceptual structure:

```text
SearchSuggestion
- type: restaurant | post | hashtag
- displayText: String
- queryText: String
- restaurantId: optional
- postId: optional
```

## Meaning
- `type` tells the UI what icon/style to use, including hashtag-style suggestion rows
- `displayText` is what the user sees in the row
- `queryText` is what gets inserted into the search bar / submitted
- `restaurantId` / `postId` are optional future hooks if later needed

## First version behavior
Even if IDs exist, tapping a suggestion should still behave as:
- populate search bar text
- submit search using that text
- navigate to SearchResultScreen

So suggestions are still query shortcuts, not direct detail-page deep links.

---

# Recommended Repository Strategy

## Step 1 — Normalize input
- trim
- lowercase
- collapse repeated spaces if helpful

## Step 2 — Short-query guard
If query length < 2:
- return empty suggestions

## Step 2B — Generate hashtag suggestion
If the normalized query is meaningful and non-empty:
- generate one hashtag suggestion like `#<normalized query>`
- example: `sushi` -> `#sushi`

This does not need a heavy database lookup in the first version.

## Step 3 — Fetch restaurant candidates
Query a limited set of matching restaurants using:
- `restaurant_name`
- maybe `address`

Apply normal visibility rules:
- `Restaurant.isDisabled = false`

## Step 4 — Rank restaurant suggestions
Apply restaurant suggestion ranking rules.

Keep only top few.

## Step 5 — Fetch post-title candidates
Query a limited set of matching posts using:
- `Post.title`

Apply visibility rules:
- `Post.isPending = false`
- `Post.isRemoved = false`
- `Post.isBlocked = false`
- linked restaurant should not be disabled if possible

## Step 6 — Rank post-title suggestions
Apply title similarity + engagement/freshness tie-breakers.

Keep only top few.

## Step 7 — Compose final suggestion list
Merge into one compact mixed list, for example:
- 3 restaurant suggestions max
- 3 post-title suggestions max

---

# Suggested UX Behavior on Suggestion Tap

When the user taps a suggestion:
1. set the search bar text to the suggestion’s `queryText`
2. move cursor to the end of the text
3. save search history as a normal submitted query
4. submit search
5. navigate to SearchResultScreen

This keeps behavior consistent with the rest of ExploreScreen.

This same behavior also applies to hashtag suggestions.
If the user taps `#sushi`, the search bar should be populated with `#sushi`, then submitted normally.

---

# Loading / Empty / Error States

## While debounce is waiting
Do nothing special yet.
Keep the current screen stable.

## While suggestions are loading
Optionally show:
- a small loading indicator
- or a lightweight shimmer/skeleton

For MVP, a small loading state is enough.

## If no suggestions are found
Show either:
- no suggestion rows at all
- or a small message like `No suggestions found`

Recommended first version:
- just show no suggestion rows and let user still submit manually

## If repository fails
Fail gracefully:
- return empty suggestions
- do not break ExploreScreen

---

# Search History vs Suggestions vs Trending

## Empty search bar
Show:
- search history
- trending

## Typing with query length < 2
Still behave close to the empty state.

## Typing with query length >= 2
Replace the empty-state content with typed suggestions.

This means:
- history/trending are for idle state
- suggestions are for active typing state

That separation is clean and intuitive.

---

# Suggested Debounce Implementation

Inside `ExploreScreen`:
- keep a `Timer? _suggestionDebounce`
- on every text change:
  - cancel previous timer
  - if query length < 2:
    - clear suggestions
    - stop
  - otherwise start 300ms timer
- when timer fires:
  - call repository
  - update suggestion state

Also:
- cancel timer in `dispose()`

This is the recommended implementation pattern.

---

# Suggested State Fields in ExploreScreen

You will likely need state such as:
- `List<SearchSuggestion> _suggestions`
- `bool _isLoadingSuggestions`
- `Timer? _suggestionDebounce`

This is enough for the first version.

---

# Important Design Principles

## 1. Suggestions must be lightweight
Do not render full result cards in ExploreScreen suggestions.

## 2. Suggestions must be fast
That is why debounce + lightweight query is important.

## 3. Suggestions should be useful shortcuts
They should help the user choose a likely search, not overwhelm them.

## 4. Suggestions do not replace full search
Full ranking still happens after submit on `SearchResultScreen`.

## 5. Do not overcomplicate first version
First version can succeed with only:
- restaurant name suggestions
- post title suggestions
- debounce
- local screen state

A lightweight generated hashtag suggestion is acceptable and useful in the first version.

---

# Recommended First-Version Implementation Plan

## ExploreScreen
Add:
- debounce timer
- suggestion state
- suggestion loading state
- render real suggestions when query length >= 2

## SearchRepository
Add lightweight method:
- `fetchSearchSuggestions(query)`

This method should return:
- top restaurant suggestions
- top post-title suggestions
- one hashtag suggestion generated from the typed query

## UI
Replace fake generated suggestions like:
- `sushi 1`
- `sushi 2`

with real suggestion rows.

---

# Final Recommendation

Taste Spot should implement typed suggestions using this pattern:

## Final pattern
TYPE -> SHORT PAUSE -> QUERY DATABASE -> SHOW REAL SUGGESTIONS

### Query timing
- debounce: 300ms
- start querying at 2+ characters

### Suggestion types
- restaurant suggestions
- post title suggestions
- hashtag suggestion

### Display style
- one mixed compact list with icons

### Tap behavior
- populate query
- submit search
- navigate to results

This is the best first-version suggestion design for your current project stage.

---

# Hashtag-Aware Search Result Behavior

Hashtag suggestions should also affect how the final search result page behaves.

## If query starts with `#`
When the final submitted query starts with `#`, Taste Spot should treat it as a hashtag-intent query.

Examples:
- `#sushi`
- `#ramen`
- `#omakase`

## Expected first-version behavior
When the query starts with `#`:
1. normalize the hashtag text
   - example: `#Sushi` -> `sushi`
2. check posts for exact hashtag matches
3. if exact hashtag matches exist:
   - prioritize those posts first
   - allow them to outrank ordinary text matches
4. if no exact hashtag matches exist:
   - continue with the normal search behavior

## Restaurant preview behavior for hashtag queries
Restaurant preview should remain strict.

However, if the hashtag query already has strong exact hashtag post matches, restaurant preview should not take priority over those hashtag-matched posts.

In other words:
- exact hashtag post matches first
- restaurant preview should not override them

## Suggestion-to-result consistency
This keeps the behavior consistent:
- user types `sushi`
- user sees suggestion `#sushi`
- user taps `#sushi`
- result page prioritizes posts with exact hashtag `sushi`
- if none exist, normal search flow still works

## First-version scope
For the first version, this hashtag-aware result behavior is enough:
- exact hashtag match gets priority in post ranking
- if none exist, fall back to normal search rules

This does not require a fully separate hashtag-only search system yet.