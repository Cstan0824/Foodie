

# Update Feed and Search Result Ranking Plan

## Purpose

This document describes the planned update for the TasteSpot feed/search ranking behavior.

There are two related goals:

1. Make the **Home Discover feed** show all eligible posts eventually, including lower-ranked posts.
2. Keep **Search Results** relevance-first, while preparing the design for future pagination if needed.

The main issue is not the ranking formula itself. The issue is **where pagination happens**.

For a ranked feed, pagination should happen **after ranking**, not before ranking.

---

## Current Concern

The Home Discover feed currently uses a ranked algorithm.

It considers factors such as:

- user saved restaurant/cuisine preferences
- location score, if phone location is available
- engagement score
- freshness score
- already-engaged penalty
- diversity control

The expected behavior is:

```text
High-ranked posts appear first.
Lower-ranked posts still appear later if the user keeps scrolling.
```

However, if the repository fetches only one database page first, then ranks only that page, lower-ranked posts may never appear.

Problem pattern:

```text
Database pagination first
→ rank only that small pool
→ return top results
```

This can cause lower-ranked posts to be pushed down repeatedly in every page and never reach the UI.

---

## Correct Feed Strategy

For Home Discover, use this strategy:

```text
Fetch a large candidate pool
→ rank all candidates
→ apply diversity ordering
→ apply offset/limit after ranking
```

This means:

```text
Page 1: ranked posts 0–19
Page 2: ranked posts 20–39
Page 3: ranked posts 40–59
```

With this approach, lower-ranked posts can still appear when the user keeps scrolling.

---

## Home Discover Feed Update

### File to update

```text
lib/data/repositories/feed_repository.dart
```

Possibly related file:

```text
lib/features/feed/screens/home_screen.dart
```

The `HomeScreen` pagination logic can stay mostly the same because it already passes:

```text
limit
offset
```

to the repository.

The main change should happen inside:

```text
FeedRepository.fetchDiscoverFeed(...)
```

---

## Required Behavior for `fetchDiscoverFeed`

The method should:

1. Fetch a large candidate pool from active posts.
2. Rank the full candidate pool.
3. Apply diversity reranking to the full ranked pool.
4. Only then apply `offset` and `limit`.
5. Return the paginated ranked result.

Recommended flow:

```text
candidatePoolSize = 300 to 500

fetch latest active posts from database range 0 to candidatePoolSize - 1
rank all fetched candidates
apply diversity to all fetched candidates
pagedRows = rankedRows.skip(offset).take(limit)
return pagedRows as PostModel list
```

Recommended candidate pool:

```text
500 active posts
```

For demo and current app scale, this is acceptable.

Later, if the app becomes larger, this can be moved to:

- server-side RPC
- cursor-based ranked pagination
- cached/materialized feed results

---

## Eligible Posts for Discover

The candidate pool should only include eligible public posts.

Use the existing filters:

```text
Post.isRemoved = false
Post.isBlocked = false
Post.isPending = false
```

Also keep any existing visibility rules already used by the repository.

Do not include:

- archived posts
- blocked posts
- pending posts
- deleted-from-owner-view posts if current queries already exclude them

---

## Ranking Formula Should Remain

Do not remove the existing ranking factors.

The Discover feed should still rank by:

```text
saved restaurant / cuisine preference
+ location score
+ engagement score
+ freshness score
- already engaged penalty
```

The already-engaged penalty means:

```text
If current user already liked/saved/commented on a post,
rank it lower because it is less new to the user.
```

But it should **not hide the post completely**.

After moving pagination to after ranking, low-ranked interacted posts should appear later when scrolling.

---

## Important: Do Not Filter Out Engaged Posts

Do not add filters like:

```text
exclude liked posts
exclude saved posts
exclude commented posts
```

That is not the desired behavior.

Desired behavior:

```text
Already engaged posts are still eligible.
They just appear lower than similar unseen posts.
```

This keeps the feed fresh without making content disappear completely.

---

## Diversity Reranking

Keep the diversity pass.

The diversity pass should also happen before pagination.

Correct order:

```text
rank candidates
→ diversify ranked candidates
→ skip(offset)
→ take(limit)
```

Not:

```text
skip(offset)
→ take(limit)
→ diversify only one page
```

This makes the whole ranked feed more balanced across restaurants/cuisines before pages are created.

---

## HomeScreen Pagination

The current HomeScreen infinite scrolling pattern can remain:

```text
initial load: offset = 0
load more: offset = current loaded post count
```

The repository must return:

```text
exactly limit posts if more ranked posts exist
less than limit posts when the candidate pool is exhausted
```

Then HomeScreen can continue using:

```text
_hasMore = returnedPosts.length == pageSize
```

No major HomeScreen rewrite should be required.

---

## Search Result Behavior

Search is different from Home Discover.

Search is query-driven and should remain relevance-first.

Current search flow is acceptable:

```text
fetch query-related candidates
→ rank candidates
→ return top results
```

Search does not currently have the same infinite-scroll pagination issue because it does not paginate through ranked results in the same way as the Home feed.

---

## Search Should Not Show Every Low-Rank Post

For Search, do not force every low-ranked or weakly related post to appear.

If the user searches:

```text
sushi
```

The result should prioritize:

- posts with `sushi` in title
- posts with `sushi` in caption
- posts with `#sushi`
- posts from sushi restaurants
- relevant restaurant matches

It should not eventually show unrelated burger/cafe posts just because the user scrolls.

Search should show:

```text
all reasonably relevant results within a controlled candidate pool
```

not:

```text
all posts in the database
```

---

## Search Future Pagination Rule

If Search Result later adds infinite scrolling or load-more behavior, use the same principle:

```text
rank first
→ paginate after ranking
```

For search, the candidate pool should be query-related.

Recommended future search flow:

```text
query = sushi

fetch search candidates:
- title/caption matches
- hashtag matches
- matched restaurant posts
- useful fuzzy/token matches

rank all query-related candidates
return rankedRows.skip(offset).take(limit)
```

Do not do:

```text
database offset first
→ rank only one raw database page
```

---

## Search Ranking Priority

Search should still prioritize exact matches, regardless of whether the current user already engaged with the post.

Important rule:

```text
Exact matches should dominate.
Engaged-post penalty should be light in Search.
```

Examples:

```text
If the user searches #sushi,
a post with exact #sushi should still rank high even if the user already liked it.
```

```text
If two sushi posts are similarly relevant,
the unseen one can rank slightly higher.
```

This keeps search useful and predictable.

---

## Recommended Next Code Change

Focus on the Home Discover feed first.

Update:

```text
FeedRepository.fetchDiscoverFeed
```

so that:

```text
offset is applied after ranking and diversity, not before ranking.
```

Search can remain as-is for now unless a dedicated search pagination feature is added later.

---

## Acceptance Criteria

### Home Discover Feed

- High-ranked posts still appear first.
- Lower-ranked posts can appear later when the user keeps scrolling.
- Already liked/saved/commented posts are not hidden completely.
- Already engaged posts are only ranked lower.
- Preference scoring still works.
- Location scoring still works when location is available.
- Engagement/freshness scoring still works.
- Diversity reranking still works.
- Infinite scroll still works.
- No duplicate posts should appear when scrolling.
- Home feed should not break if location permission is denied.

### Search Results

- Search remains relevance-first.
- Exact matches remain high priority.
- Search does not force unrelated low-rank posts to appear.
- Search can stay finite for now.
- If search pagination is added later, it should rank first and paginate after ranking.

---

## Summary

For Home Discover:

```text
Fetch large pool
→ rank all
→ diversify all
→ paginate ranked list
```

For Search:

```text
Fetch query-related candidates
→ rank by relevance
→ return best results
```

Main implementation priority:

```text
Fix Home Discover pagination inside FeedRepository.
```