

# Search Repository / Backend Search Logic Plan

## Goal
Define the backend search logic for Taste Spot.

This document is focused on:
- what data should be searched
- which records are eligible to appear
- how restaurant preview results should be decided
- how post results should be ranked
- how the mixed-result page should be composed
- what matching buckets exist
- what should be implemented first in the repository layer

This document is for a **rule-based search system**.

This is **not** a machine learning or AI-trained search algorithm.
Do not introduce:
- embeddings
- vector search
- collaborative filtering
- recommendation models
- training pipelines

The first version should be practical, deterministic, and explainable.

---

# Product Direction

Taste Spot search is a **post-first mixed search experience**.

That means:
- the main body of search results is **posts**
- **restaurants** may also appear, but only as a compact preview section at the top when there are strong enough restaurant/entity matches

Search should support user intent such as:
- restaurant name
- place / area
- food / cuisine / category
- restaurant-related discovery

However, broad food queries should still remain mostly **post-first**.

---

# Search Result Composition

## Default `All` search result page
The default search page should be composed like this:

```text
<Search bar>
<Filter tabs/buttons>
<Restaurant preview section if relevant>
<Post result masonry grid>
```

## Result-type filters
Required tabs/buttons:
- `All`
- `Restaurants`
- `Posts`

### `All`
- show restaurant preview section if strong restaurant matches exist
- then show posts below

### `Restaurants`
- show restaurant-only results

### `Posts`
- show post-only results

---

# Visibility Rules

Before any matching or ranking, exclude invalid rows.

## Restaurant eligibility
A restaurant can appear in search only if:
- `Restaurant.isDisabled = false`

## Post eligibility
A post can appear in search only if:
- `Post.isPending = false`
- `Post.isRemoved = false`
- `Post.isBlocked = false`

Recommended additional rule:
- the linked restaurant should not be disabled

This means search results should not show posts tied to inactive/disabled restaurants.

---

# Searchable Fields

## Restaurant search fields
First version restaurant matching should use:
- `Restaurant.restaurant_name`
- `Restaurant.address`

Optional later:
- `Cuisine.desc` via `Restaurant.main_cuisine_id`
- `Restaurant_Cuisine`
- rating-based tie-breakers

## Post search fields
First version post matching must include:
- `Post.title`
- `Post.caption`
- linked `Restaurant.restaurant_name`
- linked `Restaurant.address`

Optional later:
- linked `Restaurant.main_cuisine_id`
- linked `Restaurant_Cuisine`
- hashtags via `post_hashtag` + `hashtag`

---

# Query Processing Rules

Search should use both:
- **phrase matching**
- **token matching**

## Phrase matching
Check whether the full query phrase appears in the relevant field.

Examples:
- query = `sushi zanmai`
- title contains `sushi zanmai`
- restaurant name contains `sushi zanmai`

## Token matching
Split the query into tokens and compare token overlap.

Example:
- query = `best ramen setapak`
- tokens = `best`, `ramen`, `setapak`

Then compare token overlap with:
- post title
- post caption
- linked restaurant name
- linked restaurant address
- restaurant name
- restaurant address

---

# Restaurant Match Buckets

Restaurant preview should only appear when there are **high-confidence restaurant matches**.

Broad weak restaurant/cuisine matches should not aggressively trigger restaurant preview.

## R1 — Exact / exact-ish restaurant name match
A restaurant is `R1` when:
- normalized query exactly matches the restaurant name, OR
- the exact query phrase is tightly contained in the restaurant name

This bucket also includes exact-ish cases such as:
- query = `sushi zanmai`
- restaurant = `Sushi Zanmai Setapak`

These should still count as `R1 exact-ish`.

## R2 — Strong partial restaurant name match
A restaurant is `R2` when:
- token overlap with the restaurant name is strong enough
- tokens do not need to be continuous in the same order

Example:
- query = `town coffee`
- restaurant = `Old Town White Coffee`

This is still a strong restaurant match.

## R3 — Strong address/place match
A restaurant is `R3` when:
- the query is a meaningful substring of the restaurant address/place

Example:
- query = `bukit bintang`
- address contains `Bukit Bintang, Kuala Lumpur`

Substring matching is acceptable here.

## R4 — Fuzzy restaurant fallback
Fuzzy matching applies to:
- `Restaurant.restaurant_name`
- `Restaurant.address`

Examples:
- `sushi zanmi` → `Sushi Zanmai`
- `setapka` → `Setapak`

Fuzzy matching should always participate as a **lower-priority fallback**, even when stronger direct matches exist.
It should never outrank `R1`, `R2`, or `R3`.

---

# Restaurant Preview Rules

## When to show restaurant preview in default `All` mode
Show the restaurant preview section only if there are high-confidence restaurant matches from:
- `R1`
- `R2`
- `R3`
- `R4` fuzzy fallback as lower-priority support

## Important restriction
Restaurant preview should mainly be triggered by:
- restaurant name
- address/place

It should **not** mainly be triggered by broad food/cuisine/category terms alone.

## Example
### Likely show restaurant preview
- `Sushi Zanmai`
- `Setapak`
- `Old Town White Coffee`

### Usually do not force restaurant preview
- `ramen`
- `dessert`
- `cafe`

Unless there is a very strong direct restaurant/entity-style match.

## Restaurant preview ranking order
Within the restaurant preview section, rank restaurants by:
1. `R1` exact / exact-ish restaurant name match
2. `R2` strong partial restaurant name match
3. `R3` strong address/place match
4. `R4` fuzzy fallback

## Restaurant preview limit
In mixed `All` mode:
- show only **2 to 3 restaurant rows maximum**
- do not show `See all restaurants`
- if user wants more, they should switch to the `Restaurants` filter tab

## Restaurants without posts
A restaurant can still appear in the restaurant preview even if it has no posts.
Restaurant preview is not dependent on post existence.

---

# Post Match Buckets

Posts are the primary search result type.

## P1 — Exact phrase match in title
A post is in `P1` when:
- the exact query phrase is contained in `Post.title`

This does not require full-title equality.
Exact phrase containment is enough.

## P2 — Exact phrase match in caption
A post is in `P2` when:
- the exact query phrase is contained in `Post.caption`

This is slightly below exact title match.

## P3 — Exact linked restaurant name match
A post is in `P3` when:
- the linked restaurant name matches the query exactly / exact-ish

This is especially important for restaurant-name queries.

## P4 — Exact linked restaurant address/place match
A post is in `P4` when:
- the linked restaurant address/place matches the query strongly

This is especially important for place queries such as:
- `Setapak`
- `Cheras`
- `Bukit Bintang`

## P5 — Strong relevance match
A post is in `P5` when:
- it is not exact phrase match
- but token overlap and field importance make it clearly relevant

## P6 — Weak relevance match
A post is in `P6` when:
- only weaker or smaller overlap exists
- relevance is still acceptable, but weaker

---

# Post Relevance Definition

After exact matching, relevance should be based on:
- token overlap
- field importance

## Token overlap
Count how many important query tokens are matched in the searchable fields.

Example:
- query = `best ramen setapak`
- tokens = `best`, `ramen`, `setapak`

A post with stronger token overlap should rank higher.

## Field importance order
When matches happen, matches in more important fields should contribute more.

Recommended order:
1. `Post.title`
2. `Post.caption`
3. linked `Restaurant.restaurant_name`
4. linked `Restaurant.address`

This means a title match is stronger than a caption match, and a caption match is stronger than a linked restaurant address match.

---

# Fuzzy Matching Scope

## Fuzzy matching is important in first version, but scope should stay limited.

### Apply fuzzy matching to:
- restaurant name
- restaurant address/place

### Do not apply fuzzy matching yet to:
- `Post.title`
- `Post.caption`

Post matching should stay on:
- exact phrase matching
- partial token matching
- field importance

This keeps noise lower while still helping users find restaurants/places with minor typos.

---

# Broad Query Behavior

Broad food/cuisine queries should remain **post-first**.

Examples:
- `ramen`
- `dessert`
- `cafe`

## Rule
These broad queries should usually:
- show post results as the main body
- not aggressively trigger restaurant preview

Restaurant preview should still require stronger entity/location confidence.

---

# Exact Restaurant Query Behavior

If the query strongly matches a restaurant name, the result page should do two things:

## 1. Show the restaurant in the preview section
Example:
- query = `Sushi Zanmai`
- show `Sushi Zanmai` in the restaurant preview section

## 2. Boost posts linked to that restaurant
Posts whose `restaurant_Id` points to the matched restaurant should be boosted.

This makes the page feel coherent:
- restaurant entity at the top
- posts about that restaurant ranked strongly below

---

# Final Post Ranking Order

Post results should be ranked in this order:

1. **Exact match**
2. **Relevance**
3. **Engagement**
4. **Freshness**

## Exact match
Includes:
- exact phrase in title
- exact phrase in caption
- exact linked restaurant name match
- exact linked restaurant address/place match

## Relevance
Includes:
- phrase matching
- token overlap
- field importance

## Engagement
Engagement should be a **moderate boost**, not a dominant one.

Suggested engagement signals:
- `Post.likeCount`
- `Post.saveCount`

## Freshness
Freshness is the weakest ranking layer.
Use:
- `Post.created_At`

Newer posts can receive a small boost, but freshness must not outrank stronger exact/relevance signals.

## Important rule
**Exact match must beat popularity.**

If one post exactly matches the query and another post is more popular but only loosely related, the exact-match post should rank higher.

---

# Result Composition Rules

## In default `All` mode
- show restaurant preview first only if high-confidence restaurant matches exist
- then show post results below

## In `Restaurants` filter
- show restaurant-only results

## In `Posts` filter
- show post-only results

## If no restaurant preview qualifies
- omit the restaurant section entirely
- show only posts

---

# Suggested Repository Responsibilities

## `search_repository.dart`
This repository should handle:
- fetch mixed search results
- fetch restaurant-only results
- fetch post-only results
- apply visibility filtering
- classify restaurant match buckets
- classify post match buckets
- rank restaurant preview results
- rank post results
- compose the final mixed-result payload

## Recommended outputs
The search repository will likely need to return a structure similar to:
- restaurant preview results (max 2–3)
- post results
- maybe filter-aware payloads later

The exact Dart return model can be designed separately.

---

# Suggested Search Flow

## Step 1 — Normalize query
- trim
- lowercase
- normalize punctuation/spacing if possible

## Step 2 — Split query into tokens
Use both:
- full phrase
- token list

## Step 3 — Fetch candidate restaurants
Use restaurant eligibility rules.

## Step 4 — Classify restaurant match bucket
Assign each candidate into:
- `R1`
- `R2`
- `R3`
- `R4`
- or no meaningful match

## Step 5 — Decide restaurant preview
If there are enough high-confidence matches:
- sort using restaurant ranking order
- keep top 2–3 for mixed mode

## Step 6 — Fetch candidate posts
Use post eligibility rules and join linked restaurant info.

## Step 7 — Classify post exact/relevance buckets
Assign each post into:
- `P1`
- `P2`
- `P3`
- `P4`
- `P5`
- `P6`
- or irrelevant

## Step 8 — Apply restaurant-linked boost when needed
If query strongly matches a restaurant name/address:
- boost posts linked to that matched restaurant

## Step 9 — Rank posts
Use:
1. exact match
2. relevance
3. engagement
4. freshness

## Step 10 — Compose final result page
For default `All` mode:
- restaurant preview section if relevant
- post results below

---

# What This First Version Does NOT Need Yet

Do not include yet unless implementation is trivial:
- cuisine/category search as a strong ranking signal
- extra cuisine tag weighting
- hashtag ranking as a core dependency
- location-device ranking
- semantic/vector search
- full fuzzy search over post text

These can be added later.

---

# Final Summary

Taste Spot search backend should be a **rule-based mixed search**.

## Main principles
- posts are the primary result type
- restaurants appear as a compact preview only when there are high-confidence restaurant/entity matches
- restaurant preview should be selective
- broad food/cuisine queries should remain post-first
- exact match beats popularity
- post ranking order is:
  - exact
  - relevance
  - engagement
  - freshness
- fuzzy matching should help restaurant name/address matching, not full post text yet

This is the first-version search logic specification to guide repository implementation.