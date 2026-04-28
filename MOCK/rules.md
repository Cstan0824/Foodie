# TasteSpot Supabase Mock Data Generation Rules

## Purpose

This document defines what `generate_seed.py` should generate for TasteSpot demo data.

The project uses **Supabase Postgres**, so the final generated output should be a SQL seed file that can be executed in:

- Supabase SQL Editor
- Supabase CLI
- a local Supabase database

The purpose of this mock data is to make the app look presentable during demo presentation, especially for:

- Home feed
- Search results
- Post cards
- Hashtag search
- Liked posts
- Post collections

The generated data should look like a real food social app, not a testing database.

---

## Current Folder Structure

The mock folder currently contains:

```text
MOCK/
├── database/
├── generate_seed.py
└── rules.md
```

The exported Supabase SQL files are stored inside:

```text
MOCK/database/
```

Current exported files:

```text
database/
├── collections_item_rows.sql
├── collections_rows.sql
├── Comment_rows.sql
├── Cuisine_rows.sql
├── hashtag_rows.sql
├── Likes_rows.sql
├── post_hashtag_rows.sql
├── Post_Image_rows.sql
├── Post_rows (1).sql
├── Restaurant_Cuisine_rows (1).sql
├── Restaurant_Image_rows (2).sql
├── Restaurant_rows (4).sql
└── User_rows (1).sql
```

The generator should read these files only as reference/input. It should not overwrite them.

---

## Output File

`generate_seed.py` should generate a new SQL file, for example:

```text
generated_demo_seed.sql
```

This output file should contain new INSERT statements only.

The generated SQL should be compatible with Supabase Postgres.

Use double quotes for tables and columns where needed because the database uses mixed-case identifiers such as:

- `User`
- `Post`
- `Post_Image`
- `Comment`
- `Likes`
- `Restaurant`
- `Restaurant_Cuisine`
- `Restaurant_Image`
- `post_Id`
- `user_Id`
- `restaurant_Id`
- `created_At`

Example style:

```sql
INSERT INTO public."User" ("user_Id", name, bio, "created_At", password, role, username)
VALUES (...);
```

---

## Main Scope

Generate only demo post-related data.

Generate:

1. 10 new demo users
2. posts created only by those 10 demo users
3. post images using real food image URLs from the web
4. hashtags, only if needed
5. post_hashtag rows
6. likes from the 10 demo users
7. comments from the 10 demo users
8. saved post collections for the 10 demo users
9. collections_item rows for saved posts

Do not generate:

- new restaurants
- new cuisines
- restaurant images
- restaurant cuisine rows
- swipe history
- reports
- notifications
- followers
- restaurant approvals
- admin users

Use existing restaurants and cuisines from the exported Supabase SQL files.

---

## Important Demo Goal

The mock data should make these features look good:

### Home Feed

The home feed should show attractive food posts with:

- realistic captions
- good titles
- food images
- like counts
- save counts
- comments
- different users
- different restaurants
- different cuisines

### Search Results

Search should look good for predictable demo keywords such as:

- sushi
- cafe
- burger
- nasi lemak
- dessert
- korean
- thai
- noodles
- #sushi
- #dessert
- #cafe

Each major demo keyword should have multiple matching posts.

### Liked Posts

The generated likes should make the profile liked-post section meaningful.

### Collections

The generated saved post collections should make post collection pages meaningful.

---

## Data Source Rules

### Existing SQL files

The generator should parse existing SQL export files to extract IDs and names.

Required input files:

| File | Purpose |
|---|---|
| `User_rows (1).sql` | avoid duplicate usernames |
| `Restaurant_rows (4).sql` | get existing restaurant IDs and names |
| `Cuisine_rows.sql` | get existing cuisine IDs and names |
| `Restaurant_Cuisine_rows (1).sql` | understand restaurant cuisine tags if needed |
| `hashtag_rows.sql` | avoid duplicate hashtags |
| `collections_rows.sql` | avoid duplicate collection names if needed |

Optional input files:

| File | Purpose |
|---|---|
| `Post_rows (1).sql` | avoid duplicate-looking post titles if desired |
| `Likes_rows.sql` | avoid duplicate like rows if mixing with existing data |
| `Comment_rows.sql` | not required, but can be used for reference |
| `post_hashtag_rows.sql` | not required, but can be used for reference |

---

## Generated Users

Generate exactly **10 new users**.

Rules:

- Insert into `public."User"`
- Generate new UUIDs in Python
- Do not reuse existing user IDs
- Do not reuse existing usernames
- All generated users should have role `user`
- Password can use the existing default/simple value pattern used in the database
- Bios must be short and under the database limit
- These 10 users are the only users used for generated posts, likes, comments, and saves

Suggested demo users:

| Name | Username | Bio idea |
|---|---|---|
| Chloe Tan | chloe_eats | Cafe hopping around KL. |
| Ryan Lim | ryan_nomnom | Always searching for good noodles. |
| Maya Wong | maya_munch | Dessert and brunch lover. |
| Adam Lee | adam_bites | Burger and western food fan. |
| Sara Ng | sara_spicy | Loves spicy food and Thai dishes. |
| Daniel Ho | daniel_sushi | Japanese food explorer. |
| Nina Koh | nina_kfood | Korean food and street snacks. |
| Marcus Teo | marcus_local | Local Malaysian food hunter. |
| Emily Chan | emily_cafe | Coffee, cakes, and cozy corners. |
| Jason Yap | jason_supper | Supper spots and late-night eats. |

The script may slightly change names/usernames if needed to avoid conflicts.

---

## Restaurant Usage

Do not create new restaurants.

Use existing restaurant IDs from:

```text
Restaurant_rows (4).sql
```

Rules:

- Every generated post must reference an existing `Restaurant.restaurant_Id`
- Prefer restaurants with readable `restaurant_name`
- Prefer restaurants that are not disabled
- If possible, spread posts across many restaurants
- Do not generate all posts for one restaurant

Suggested distribution:

- 30 to 60 generated posts total
- Use at least 15 different restaurants if available
- Each restaurant can have 1 to 4 posts

---

## Cuisine Usage

Do not create new cuisines.

Use existing cuisine rows from:

```text
Cuisine_rows.sql
```

Cuisine data can help the script decide what type of captions, titles, and hashtags to generate.

For example:

- Japanese restaurant → sushi, ramen, don, matcha
- Cafe → coffee, cake, brunch, dessert
- Western → burger, fries, pasta, steak
- Malaysian → nasi lemak, chicken rice, laksa
- Korean → kimchi, fried chicken, tteokbokki
- Thai → tom yum, basil rice, spicy dishes

If cuisine mapping is unclear, still generate generic food captions based on restaurant name.

---

## Generated Posts

Generate new rows in `public."Post"`.

Rules:

- Every post must use one of the 10 new demo users as `user_Id`
- Every post must use an existing restaurant as `restaurant_Id`
- Generate a new UUID for every `post_Id`
- Use realistic titles
- Use realistic captions
- Use clean English
- Include hashtags naturally in the caption or through post_hashtag rows
- Avoid placeholder text such as `test`, `hello`, `abc`, `blabla`
- Set `isRemoved = false`
- Set `isBlocked = false`
- Set `isPending = false`
- Set `visible_to_owner = true`
- Set `restaurant_approval_id = null`
- `updated_At` can be null

Post date distribution:

- Some posts from today
- Some posts from yesterday
- Some posts from the past week
- Some posts from the past month

This helps the feed freshness ranking look natural.

Suggested generated amount:

```text
40 to 60 posts
```

Suggested title examples:

- Creamy Salmon Mentai Don
- Hidden Cafe Worth Visiting
- Crispy Chicken Burger Stack
- Spicy Thai Basil Rice
- Classic Nasi Lemak Fix
- Matcha Latte and Burnt Cheesecake
- Late Night Ramen Craving
- Korean Fried Chicken Night
- Cozy Brunch Spot
- Best Supper Noodles

Suggested caption examples:

- Rich, creamy, and perfectly torched. Great spot for a quick Japanese dinner.
- Cozy corner, strong latte, and a surprisingly good burnt cheesecake.
- Juicy patty, crispy fries, and extra sauce. Perfect for supper cravings.
- Fragrant basil, spicy minced chicken, and a crispy egg on top.
- Crispy anchovies, sambal with a kick, and tender ayam goreng.

---

## Generated Post Images

Generate at least one row in `public."Post_Image"` for every generated post.

Rules:

- Generate a new UUID for every `image_Id`
- `post_Id` must reference a generated post
- `image_url` should be a real public food image URL from the web
- Every generated post must have at least 1 image
- Some posts can have 2 or 3 images

Image URL rules:

- Use stable direct image URLs when possible
- Do not use local file paths
- Do not use empty placeholder URLs
- Do not use broken image links
- Prefer food-related images matching the post theme

Acceptable sources:

- Unsplash image URLs
- Pexels image URLs
- Wikimedia Commons food images
- other stable public direct food image URLs

For demo purposes, random real food images are acceptable.

---

## Generated Hashtags

Use existing hashtags if they already exist.

Generate new hashtag rows only when needed.

Insert into `public.hashtag`.

Rules:

- Generate new UUID for `hashtag_id`
- Store hashtag name according to the current project format
- Prefer lowercase names without `#` if that matches existing data
- Avoid duplicates with existing `hashtag_rows.sql`

Recommended hashtags:

- sushi
- japanese
- cafe
- coffee
- dessert
- burger
- western
- nasilemak
- malaysian
- localfood
- korean
- thai
- spicy
- noodles
- brunch
- halal
- supper
- matcha
- ramen
- chickenrice
- friedchicken
- pasta
- cake

---

## Generated post_hashtag Rows

Generate rows in `public.post_hashtag`.

Rules:

- Every generated post should have 2 to 4 hashtags
- `post_Id` must reference a generated post
- `hashtag_id` must reference an existing or generated hashtag
- Do not create duplicate `(post_Id, hashtag_id)` pairs

This is important because hashtag tapping and search results need to look good.

---

## Generated Likes

Generate rows in `public."Likes"`.

Rules:

- Use only the 10 new demo users
- Users can like posts created by other demo users
- Users should not like their own posts too often
- Do not create duplicate `(post_Id, user_Id)` pairs
- `created_At` should be realistic and near/after the post creation time
- `Post.likeCount` must match the number of generated Likes for each generated post

Suggested distribution:

| Post type | Like count |
|---|---:|
| Highly engaging demo posts | 6 to 9 likes |
| Normal posts | 2 to 5 likes |
| Low/new posts | 0 to 2 likes |

The like distribution should make home feed engagement ranking look realistic.

---

## Generated Comments

Generate rows in `public."Comment"`.

Rules:

- Generate a new UUID for `comment_Id`
- `post_Id` must reference a generated post
- `user_Id` must be one of the 10 demo users
- Avoid users commenting on their own posts too often
- `content` should be realistic
- `created_At` should be after the post creation time
- `isBlocked = false`

Suggested distribution:

| Post type | Comment count |
|---|---:|
| Highly engaging posts | 3 to 6 comments |
| Normal posts | 1 to 3 comments |
| Low/new posts | 0 to 1 comment |

Example comments:

- This looks so good!
- Need to try this place soon.
- The portion looks worth it.
- Adding this to my food list.
- That sauce looks amazing.
- Perfect supper spot.
- The plating is really nice.
- I love this cafe vibe.
- This looks like a great weekend spot.
- The price looks pretty reasonable.

---

## Generated Saved Posts

Saved posts should be represented using `collections` and `collections_item`.

Generate saved post collections only.

Do not generate saved restaurant collections for this version.

### collections

Generate one default-style post collection for each of the 10 demo users if needed.

Insert into `public.collections`.

Rules:

- Generate new UUID for `collection_Id`
- `user_Id` must be one of the 10 demo users
- `collection_type = 'POST'`
- `is_default = true` for the generated saved-post collection
- `name` can be `Saved Posts`
- `description` can be simple or null
- `is_public` can be true or false depending on current app behavior, but keep it consistent
- `created_At` should be realistic

### collections_item

Generate saved post rows in `public.collections_item`.

Rules:

- Generate new UUID for `item_Id`
- `collection_Id` must reference one of the generated post collections
- `post_id` must reference a generated post
- `restaurant_id = null`
- `savedAt` should be after the post creation time
- Do not duplicate the same saved post in the same collection
- `Post.saveCount` must match the number of generated saved-post collection items for that generated post

Suggested distribution:

| Post type | Save count |
|---|---:|
| Highly saveable posts | 4 to 8 saves |
| Normal posts | 1 to 3 saves |
| Low/new posts | 0 to 1 save |

Saved posts are enough for this mock data version.

---

## Count Consistency Rules

The generated `Post.likeCount` and `Post.saveCount` must match generated interaction rows.

For every generated post:

```text
likeCount = number of generated Likes rows for that post
saveCount = number of generated collections_item rows where post_id = that post
```

Do not create inconsistent counts.

This is important because the feed ranking uses likes and saves.

---

## Demo Search Planning

The script should intentionally create posts that support good demo searches.

Target demo queries:

```text
sushi
cafe
burger
nasi lemak
dessert
korean
thai
noodles
#sushi
#dessert
#cafe
```

Each target query should have at least 3 to 5 matching posts if possible.

Search matching can come from:

- post title
- post caption
- restaurant name
- hashtags

---

## Demo Feed Planning

The generated data should make the home feed look active and varied.

Use a mix of:

- recent posts
- slightly older posts
- high engagement posts
- low engagement posts
- different cuisines
- different restaurants
- different users

Do not make all posts have the same number of likes/saves/comments.

Do not make all posts created at the same timestamp.

---

## SQL Safety Rules

The generated SQL should be safe to run in Supabase.

Rules:

- Use valid UUID strings
- Escape single quotes in text values
- Use `NULL` for null values, not empty strings unless intentional
- Use proper boolean values: `true` / `false`
- Use timestamp strings compatible with Postgres
- Use semicolons after SQL statements
- Prefer grouped multi-row INSERT statements where practical
- Keep output readable

Optional but recommended:

- Wrap generated seed inserts in a transaction:

```sql
BEGIN;
-- inserts
COMMIT;
```

Do not include destructive commands such as:

- DELETE
- TRUNCATE
- DROP
- ALTER TABLE

The generated seed should only insert new demo rows.

---

## Generation Order

The generated SQL should insert rows in this order:

1. User
2. hashtag, only new hashtags if needed
3. Post
4. Post_Image
5. post_hashtag
6. Likes
7. Comment
8. collections
9. collections_item

This order avoids foreign key issues.

---

## Script Requirements for `generate_seed.py`

The Python script should:

1. Read SQL files from `MOCK/database/`
2. Parse existing restaurant IDs and names
3. Parse existing cuisine IDs and descriptions if useful
4. Parse existing hashtag names and IDs
5. Parse existing usernames to avoid duplicates
6. Generate 10 new users
7. Generate 40 to 60 posts using existing restaurants
8. Generate post images with real food image URLs
9. Generate hashtags and post_hashtag rows
10. Generate likes using only the 10 new users
11. Generate comments using only the 10 new users
12. Generate post collections for the 10 new users
13. Generate saved post collection items
14. Ensure likeCount and saveCount match generated rows
15. Write everything into `generated_demo_seed.sql`

The script should print a summary after generation:

```text
Generated users: 10
Generated posts: 50
Generated post images: 65
Generated hashtags: 20
Generated likes: 180
Generated comments: 90
Generated collections: 10
Generated saved posts: 120
Output: generated_demo_seed.sql
```

---

## Prompt for Codex

Use this prompt to ask Codex to implement `generate_seed.py`:

```text
Write the Python script `generate_seed.py` for the TasteSpot Supabase mock data generator.

Read the detailed rules from `MOCK/rules.md` and implement the generator accordingly.

The exported Supabase SQL files are inside `MOCK/database/`.

The script should generate a new SQL file called `generated_demo_seed.sql`.

Main requirements:
- Generate 10 new demo users with new UUIDs.
- Only use those 10 users for generated posts, likes, comments, and saved posts.
- Use existing restaurants from `Restaurant_rows (4).sql`.
- Use existing cuisines from `Cuisine_rows.sql` only for context; do not insert new cuisines.
- Generate 40 to 60 realistic food posts.
- Every generated post must reference an existing restaurant.
- Every generated post must have at least one post image.
- Use real public food image URLs from the web.
- Generate hashtags if needed, but avoid duplicates with existing hashtags.
- Generate post_hashtag rows for every generated post.
- Generate Likes rows using only the 10 demo users.
- Generate Comment rows using only the 10 demo users.
- Generate one saved-post collection for each demo user.
- Generate collections_item rows for saved posts only.
- Do not generate saved restaurant rows.
- Ensure Post.likeCount equals generated Likes count per post.
- Ensure Post.saveCount equals generated saved-post count per post.
- Do not generate restaurants, cuisines, reports, notifications, followers, swipe history, or restaurant approvals.
- Output valid Supabase/Postgres SQL.
- Use quoted identifiers for mixed-case table and column names.
- Do not include DELETE, TRUNCATE, DROP, or ALTER statements.
- Print a generation summary at the end.

Make the generated data presentable for demo:
- realistic food titles
- realistic captions
- useful hashtags
- varied cuisines/restaurants
- varied engagement counts
- varied created dates
- good demo search keywords such as sushi, cafe, burger, nasi lemak, dessert, korean, thai, noodles, #sushi, #dessert, #cafe
```

---

## Final Reminder

This mock generator is for Supabase demo seeding.

The output should be reviewed before running in Supabase SQL Editor.

The goal is a controlled, presentable dataset for demo, not a massive random dataset.
