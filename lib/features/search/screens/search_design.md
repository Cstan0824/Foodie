

# Search Result Page UI/UX Plan

## Goal
Define the UI/UX structure and user flow for the Taste Spot search result page.

This document is focused on:
- search result page layout
- result types shown on the page
- section ordering
- filter behavior
- screen states
- what the user should experience visually

This document is **not** about backend search scoring or result decision logic yet.
That backend logic will be discussed separately.

---

# Product Direction for Search

Taste Spot search is not intended to be only a restaurant-name finder.
It is primarily a **content discovery search**, with restaurant entity matches shown as a compact supporting section.

That means:
- the **primary result type** of search is **posts**
- **restaurant matches** can also appear, but as a smaller preview section

So the search result page is a **mixed-result page by default**.

---

# Default Search Result Structure

When the user enters a query and search results are shown, the layout should be:

```text
<Search bar>
<Filter buttons / tabs>
<Restaurant preview section if relevant>
<Post bento results>
```

This means the page should not immediately split restaurants and posts into separate screens.
Instead, the user first sees one combined page.

---

# Search Result Types

## 1. Restaurant Results
Restaurant results use a **row/list layout**.

These are intended to show direct restaurant matches, such as:
- restaurant name match
- place/address-related match
- cuisine/category-related restaurant match
- other restaurant-level matches depending on the future search algorithm

Restaurant results are shown as a **small preview section** at the top of the search result page, only when relevant.

## 2. Post Results
Post results use a **2-column masonry-like layout**.

These are the main search results and should visually dominate the page.

Posts are the primary result type because the app is mainly a restaurant-based social/content discovery app.

---

# Default Mixed Result Behavior

## In default search mode
The search result page should show:
- a compact restaurant preview section first, **if relevant**
- then the post result masonry layout below

This is the normal mixed-result layout.

## Important product rule
The system decides whether restaurant rows should appear at the top.
That decision depends on the search logic/algorithm, which is not defined in this document yet.

For now, this UI/UX document only defines:
- how the page should look if restaurant results are shown
- how the page should behave if they are not shown

---

# Page Layout Details

## 1. Search Bar
The search bar stays at the top of the page.

### Purpose
- show the current search query
- allow query editing
- allow user to clear query
- allow user to submit a new search

### Expected behavior
- if user edits the query, results should update according to the future search behavior
- search bar should remain visible while browsing results
- search bar is always the main entry point of the search page

---

## 2. Filter Buttons / Tabs
Below the search bar, provide result-type filters.

### Required filters
At minimum:
- `All`
- `Restaurants`
- `Posts`

### Behavior
#### `All`
- show the mixed-result page
- restaurant preview section first if relevant
- posts bento layout below

#### `Restaurants`
- show only restaurant list results
- hide post results

#### `Posts`
- show only post masonry results
- hide restaurant preview section

### Notes
These filters are for result-type control, not backend ranking logic.
Backend matching logic will be handled later.

---

# Restaurant Result Section

## Purpose
Show a small number of direct restaurant matches above the post results.

This section is a quick preview, not the full restaurant search page.

## Section title
Show a visible title:
- `Restaurants`

Only the restaurant section needs a title.

There is **no need for a `Posts` section title**, because posts are already the main result body and users can naturally understand that.

## Maximum number of restaurant rows
Show only:
- **2 to 3 restaurant rows maximum**

Do not show a `See all restaurants` button.

### Reason
If the user wants only restaurants, they should switch to the:
- `Restaurants` filter tab

This keeps the mixed result page compact and prevents restaurant rows from pushing the post results too far down.

## Restaurant row layout
Each restaurant row should use a compact list/row design.

Recommended row contents:
- cover image thumbnail
- restaurant name
- short address or area
- main cuisine / category
- optional supporting metadata later

### Interaction
- tapping a restaurant row should open the restaurant detail page

## When this section should appear
- only when the search logic decides restaurant matches are relevant enough to show

If there are no relevant restaurant results, the restaurant section should be omitted entirely.

---

# Post Result Section

## Purpose
Show the main search result body.

This section displays post content related to the search query.

## Layout style
Use a:
- **2-column masonry-like layout**

This is important.
Do not use a plain text list for post results.

## Why masonry-like layout
This layout better fits:
- image-heavy post cards
- social content discovery
- variable visual height content
- a richer and more engaging search experience

## Section title
Do **not** show a `Posts` title.

Reason:
- posts are the primary result type
- users will already understand that the main body of the results is post content
- this keeps the page cleaner

## Interaction
- tapping a post card should open the post detail page

---

# Filtered Result Behavior

## All filter
Show:
- restaurant preview section first if relevant
- post masonry layout below

This is the default mixed-result result page.

## Restaurants filter
Show:
- restaurant-only results
- full restaurant list layout
- no post results

## Posts filter
Show:
- post-only results
- masonry layout only
- no restaurant rows

---

# Empty / No Result Behavior

## Case 1: No results at all
If the query returns nothing:
- show a clean no-results state
- example meaning: no restaurants and no posts matched

Suggested message style:
- `No results found for "<query>"`

## Case 2: Restaurants available, but no posts
If restaurant results exist but post results do not:
- show the restaurant section only
- do not show an empty post section placeholder unless necessary

## Case 3: Posts available, but no restaurant preview rows
If post results exist but restaurant results do not:
- show only the post masonry layout
- omit the restaurant section completely

## Case 4: Filter-specific empty state
If user switches to a filter tab and that filter has no results:
- show a result-specific empty state for that filter

Example:
- restaurant filter selected but no restaurant matches
- post filter selected but no post matches

---

# Result Page User Flow

## Flow 1: User searches normally
1. user enters a search query
2. search page opens or updates with results
3. user sees:
   - search bar
   - filter tabs
   - restaurant preview section if relevant
   - post masonry results below
4. user can tap a restaurant or post result

## Flow 2: User only wants restaurant results
1. user enters search query
2. default mixed page appears
3. user taps `Restaurants` filter
4. page switches to restaurant-only results

## Flow 3: User only wants post results
1. user enters search query
2. default mixed page appears
3. user taps `Posts` filter
4. page switches to post-only masonry results

## Flow 4: User edits query from result page
1. user changes search text in the search bar
2. results update according to the future search behavior
3. same UI structure remains in place

## Flow 5: No results found
1. user enters a query
2. no valid results are found
3. page shows a no-results state instead of blank content

---

# UX Principles for This Page

## 1. Posts are primary
The page should visually feel like a **post-first search experience**.
Restaurant rows are a smaller supporting section.

## 2. Restaurant rows are quick entity matches
The restaurant section is meant to quickly expose direct restaurant matches without taking over the page.

## 3. Compact restaurant preview
The restaurant section must stay compact.
That is why:
- only 2–3 rows are shown in mixed mode
- no `See all restaurants`
- restaurant-only browsing happens through the filter tab

## 4. Visual discovery matters
The post section should feel visually rich and content-driven.
That is why the masonry-like card layout is important.

## 5. Hide unused sections when unnecessary
If one result type does not exist:
- omit that section
- do not leave awkward empty blocks

---

# Implementation Notes

## This document does define
- result page structure
- result type ordering
- filter behavior
- section visibility rules
- user flow

## This document does NOT define yet
- backend ranking/scoring logic
- exact rules for when restaurants should appear in the mixed result page
- search indexing/query strategy
- post relevance scoring
- restaurant relevance scoring

Those backend/search-decision rules will be discussed separately.

---

# Final UI/UX Summary

The default Taste Spot search result page should be a **mixed-result page**.

### Final layout
- search bar
- filter buttons/tabs
- restaurant preview section with title `Restaurants` if relevant
  - max 2–3 rows
- post results in a 2-column masonry-like layout
  - no `Posts` title

### Key behavior
- posts are the primary result type
- restaurants are supporting entity matches shown at the top when relevant
- users can switch to `Restaurants` or `Posts` filter tabs if they want only one result type
- the system decides whether restaurant rows appear, but that logic is not covered in this document yet