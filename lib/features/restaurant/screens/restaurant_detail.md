# Restaurant Detail Page Structure Plan

## Goal
Refine `restaurant_detail_screen.dart` so the page uses a stable layout pattern:
- `Column`
- `Expanded`
- bottom `SafeArea`

This structure is needed because the page should have:
- a scrollable content area
- a fixed bottom action area
- the bottom action should always stay visible
- the scroll content should end ABOVE the bottom action

This is especially important for the `See Related Posts` button.

---

# Main Layout Pattern

The page should use this overall structure conceptually:

```text
CupertinoPageScaffold
  SafeArea
    Column
      Expanded
        scrollable restaurant detail content
      bottom SafeArea(top: false)
        fixed bottom action section
```

## Why this pattern
This is better than putting the button inside the scroll view.

### Desired behavior
- the restaurant detail content scrolls normally
- the bottom action area does NOT scroll away
- the bottom action area always remains visible
- the content never gets hidden behind the button
- the bottom area respects iPhone safe area / home indicator area

## Important note
The scroll view should be inside `Expanded`, not the other way around.
This ensures the content area uses the remaining height after reserving space for the fixed bottom action section.

---

# Final Page Structure

## 1. Top-level page layout
The screen should be divided into 2 large sections:

### A. Scrollable content section
This should contain all restaurant information.

### B. Fixed bottom action section
This should contain the main call-to-action button:
- `See Related Posts`

The bottom action section should stay visible at all times.

---

# 2. Scrollable content section
This is the main restaurant detail content and should be wrapped inside:
- `Expanded`
- then `SingleChildScrollView`

## Content order inside scroll area

### Section 1 — Hero carousel
The top image area should be a carousel slider.

Rules:
- cover image should be the first image
- all restaurant images should appear in the slider
- no separate gallery section below
- maintain the current "size" of the hero image area
- refer to `restaurant_detail_screen.dart` for an example implementation of the carousel slider

This is the visual hero area of the screen.

### Section 2 — Basic identity section
This section should appear directly below the carousel.

#### Content order inside this section
1. rating + distance row
2. restaurant name
3. short info row
   - main cuisine only
   - price range only
4. description / about us

#### Notes
- distance is computed only when user location is available
- price range should display values like:
  - `RM 20-40`
  - `RM 200+`
- do NOT put all cuisine tags in this short row
- only show the MAIN cuisine here
- keep this row visually short and clean

### Section 3 — Extra cuisine tags section
This section should appear AFTER the description.

Purpose:
- show the extra cuisine tags
- avoid overcrowding the basic identity section

Rules:
- main cuisine already appears above, so do not repeat it unnecessarily unless needed by design
- this section can be a wrap/chip section
- this section is for secondary / additional cuisine tags

### Section 4 — Location section
This section should show:
- full address
- `Open in Maps` button
- optional `Visit their website` button if `info_url` exists

Mapping:
- maps button should use `maps_url`
- website button should use `info_url`

### Section 5 — Optional spacing at bottom of scroll content
Even though the bottom CTA is outside the scroll area, the content should still have comfortable bottom spacing before the fixed action section.

This prevents the last content block from feeling visually cramped against the bottom CTA.

---

# 3. Fixed bottom action section
This section should be OUTSIDE the scrollable content.

It should be the last child of the top-level `Column`.

## Wrapper
Use a bottom safe-area wrapper conceptually like:
- `SafeArea(top: false)`

This ensures:
- the button does not collide with the home indicator area
- the bottom section feels native on iOS

## Content of fixed bottom section
This section should primarily contain:
- one main button: `See Related Posts`

## Button behavior
When tapped:
- navigate to `SearchResultScreen`
- pass query as:
  - `restaurant: <restaurant_name>`

Later, search result logic will interpret this specially to show all posts tied to that restaurant.

## Why fixed bottom CTA is preferred
This button should not live inside the page content because:
- it is a main action
- users may want it immediately without scrolling
- the restaurant detail page is partly informational, but also action-driven

So this action should always remain accessible.

---

# 4. What should NOT be in the page anymore

## Remove menu section
Do not show menu items.

Reason:
- menu is removed from the design

## No separate image gallery section below
Do not add another gallery section below.

Reason:
- the hero carousel already handles the image browsing

## No source display section
Do not show source text or original source metadata as a separate visible section.

Reason:
- source is not needed in the UI
- only website action matters if `info_url` exists

## No bottom CTA inside scroll view
Do not place `See Related Posts` inside the page content.

Reason:
- it should be fixed at the bottom of the screen

---

# 5. Detailed section-by-section visual intent

## Hero carousel section
Purpose:
- visually establish the restaurant immediately
- make the detail page feel rich and image-led

Should include:
- all restaurant images
- cover image first
- existing slider design can be reused if already implemented (refer to `restaurant_detail_screen.dart` for the carousel slider example)
- the hero image area should retain its current size

## Rating + distance row
Purpose:
- show quick quality + location relevance immediately

Examples:
- `4.5 ★`
- `1.2 km away`

Distance should only appear when user location is available.

## Restaurant name
Purpose:
- primary identity
- should be visually dominant

## Short info row
This row should be short and not overloaded.

Only show:
- main cuisine
- price range

Example:
- `Japanese • RM 20-40`
- `Steakhouse • RM 200+`

This row should remain concise.

## Description / About us
Purpose:
- provide a short readable summary of the place

Source:
- database `description`

## Extra cuisine tags section
Purpose:
- show other associated cuisines without crowding the hero identity area

Examples:
- Sushi
- Omakase
- Ramen
- Izakaya

This should be visually secondary to the main identity row.

## Address / actions section
Purpose:
- practical navigation and off-platform visit actions

Should show:
- full address text
- `Open in Maps`
- `Visit their website` if `info_url` exists

---

# 6. Data mapping (Mock Data for Now)

**Note:** For the current phase, the app uses mock data. The current entry point for the restaurant detail page is from `lib/features/restaurant/screens/blind_box_screen.dart`, which passes a mock restaurant map. Until the database is fully connected, continue to use the mock data passed via the widget's parameters.

## From `Restaurant` (Future Database Mapping)
Use:
- `restaurant_name`
- `description`
- `rating`
- `price_range`
- `address`
- `maps_url`
- `info_url`

## From `Restaurant_Image`
Use:
- all images for carousel
- cover image first

## From cuisine tables
Use:
- one MAIN cuisine for the short identity row
- extra cuisines for the later extra-tags section

## Computed
Use:
- distance from user location to restaurant coordinates when available

---

# 7. Detailed implementation expectations for `restaurant_detail_screen.dart`

## Required structural change
The current screen should be reorganized so the content is no longer a single full-screen scroll body with the action button inside it.

Instead, it should become:

### Top-level layout
- one `Column`
- first child = `Expanded(...)`
- second child = bottom `SafeArea(...)`

### Inside `Expanded`
- place the existing scrollable restaurant detail content
- keep most of the current design sections if already built
- just reorder / trim them to match the new agreed structure

### Inside bottom `SafeArea`
- add the persistent `See Related Posts` button section
- this section should have its own padding/background/divider if needed
- this section should visually feel like a stable bottom action bar

---

# 8. Styling / spacing expectations

## Bottom section spacing
The fixed bottom action area should have:
- horizontal padding
- top padding
- bottom safe-area spacing

It should not feel cramped.

## Separation from content
The bottom action area should be visually separated from the scroll content.

Possible ways:
- light top border/divider
- subtle background difference
- shadow if needed

Keep it clean and not too heavy.

## Content spacing
The scroll content should still have good vertical spacing between:
- hero image
- identity section
- description
- extra tags
- location section

---

# 9. Navigation behavior for bottom CTA

## Button label
Use something like:
- `See Related Posts`

## Action
Navigate to:
- `SearchResultScreen`

## Query format
Pass:
- `restaurant: <restaurant_name>`

This is the agreed query contract for later logic.

---

# 10. Final summary

`restaurant_detail_screen.dart` should be refactored to use:
- `Column`
- `Expanded`
- bottom `SafeArea`

so that:
- all restaurant details scroll inside the upper content area
- the `See Related Posts` button stays fixed and always visible at the bottom
- the page structure aligns with the current database and design decisions

## Final section order
1. image carousel
2. rating + distance row
3. restaurant name
4. short info row
   - main cuisine
   - price range
5. description
6. extra cuisine tags section
7. address + maps / website actions
8. fixed bottom `See Related Posts` action section

## Important implementation note
Most of the existing UI can be reused.
The main change is the PAGE STRUCTURE and CTA PLACEMENT, not a total redesign of every internal widget.
