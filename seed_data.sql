-- Single-post seed data for feed, comment thread, and moderation testing.
-- This fixture creates:
-- 1. One visible post only
-- 2. Multiple comments under that same post
-- 3. Multiple reports on the same post
-- 4. Multiple reported comments under that same post
-- 5. A follow relationship so the post appears in the Following tab

-- Cleanup old fixture rows so rerunning this file keeps the dataset focused on
-- one post instead of accumulating earlier seed variants.
DELETE FROM public."Report"
WHERE "post_Id" IN (
  'aaaa1111-0000-0000-0000-000000000000',
  'bbbb2222-0000-0000-0000-000000000000',
  'cccc3333-0000-0000-0000-000000000000',
  'dddd4444-0000-0000-0000-000000000000'
)
   OR "comment_Id" IN (
  'eeee5555-0000-0000-0000-000000000001',
  'eeee5555-0000-0000-0000-000000000002',
  'eeee5555-0000-0000-0000-000000000003',
  'eeee5555-0000-0000-0000-000000000004'
);

DELETE FROM public."Likes"
WHERE "post_Id" IN (
  'aaaa1111-0000-0000-0000-000000000000',
  'bbbb2222-0000-0000-0000-000000000000',
  'cccc3333-0000-0000-0000-000000000000',
  'dddd4444-0000-0000-0000-000000000000'
);

DELETE FROM public."Comment"
WHERE "comment_Id" IN (
  'eeee5555-0000-0000-0000-000000000001',
  'eeee5555-0000-0000-0000-000000000002',
  'eeee5555-0000-0000-0000-000000000003',
  'eeee5555-0000-0000-0000-000000000004'
);

DELETE FROM public."Post_Image"
WHERE "post_Id" IN (
  'aaaa1111-0000-0000-0000-000000000000',
  'bbbb2222-0000-0000-0000-000000000000',
  'cccc3333-0000-0000-0000-000000000000',
  'dddd4444-0000-0000-0000-000000000000'
);

DELETE FROM public."Post"
WHERE "post_Id" IN (
  'aaaa1111-0000-0000-0000-000000000000',
  'bbbb2222-0000-0000-0000-000000000000',
  'cccc3333-0000-0000-0000-000000000000',
  'dddd4444-0000-0000-0000-000000000000'
);

DELETE FROM public."Follower"
WHERE "follower_Id" = '00000000-0000-0000-0000-000000000001'
  AND "following_Id" = '00000000-0000-0000-0000-000000000002';

-- Users
INSERT INTO public."User" ("user_Id", "name", "bio") VALUES
('00000000-0000-0000-0000-000000000001', 'Test User', 'Hardcoded local test user.'),
('00000000-0000-0000-0000-000000000002', 'Alice Smith', 'Food blogger based in KL.'),
('00000000-0000-0000-0000-000000000003', 'Bob Jones', 'Loves spicy food and coffee.'),
('00000000-0000-0000-0000-000000000004', 'Chloe Tan', 'Weekend cafe hopper.'),
('00000000-0000-0000-0000-000000000005', 'Daniel Lim', 'Burger and ramen enthusiast.'),
('00000000-0000-0000-0000-000000000006', 'Eva Wong', 'Always hunting for dessert spots.')
ON CONFLICT ("user_Id") DO NOTHING;

-- Cuisine
INSERT INTO public."Cuisine" ("type_id", "desc", "isPrimaryOption") VALUES
('10000000-0000-0000-0000-000000000001', 'Japanese', true)
ON CONFLICT ("type_id") DO NOTHING;

-- Restaurant
INSERT INTO public."Restaurant" (
  "restaurant_Id",
  "restaurant_name",
  "address",
  "maps_url",
  "main_cuisine_id"
) VALUES
(
  '11111111-1111-1111-1111-111111111111',
  'Sakura Sushi Bar',
  '123 Main St, Kuala Lumpur',
  'https://maps.google.com/?q=Sakura+Sushi+Bar',
  '10000000-0000-0000-0000-000000000001'
)
ON CONFLICT ("restaurant_Id") DO NOTHING;

-- Following relationship so Test User can see Alice's post in the Following tab
INSERT INTO public."Follower" ("follower_Id", "following_Id") VALUES
('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002')
ON CONFLICT ("follower_Id", "following_Id") DO NOTHING;

-- One post only
INSERT INTO public."Post" (
  "post_Id",
  "user_Id",
  "restaurant_Id",
  "title",
  "caption",
  "likeCount",
  "saveCount",
  "isRemoved",
  "isBlocked",
  "isPending"
) VALUES
(
  'aaaa1111-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000002',
  '11111111-1111-1111-1111-111111111111',
  'Amazing Sushi Night',
  'The omakase here was incredible. Super fresh and worth the queue.',
  4,
  1,
  false,
  false,
  false
)
ON CONFLICT ("post_Id") DO NOTHING;

-- Post images
INSERT INTO public."Post_Image" ("image_Id", "post_Id", "image_url") VALUES
('dddd4444-0000-0000-0000-000000000001', 'aaaa1111-0000-0000-0000-000000000000', 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=800'),
('dddd4444-0000-0000-0000-000000000002', 'aaaa1111-0000-0000-0000-000000000000', 'https://images.unsplash.com/photo-1553621042-f6e147245754?q=80&w=800')
ON CONFLICT ("image_Id") DO NOTHING;

-- Multiple comments on the same post
INSERT INTO public."Comment" ("comment_Id", "post_Id", "user_Id", "content", "isBlocked") VALUES
(
  'eeee5555-0000-0000-0000-000000000001',
  'aaaa1111-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000003',
  'This looks overrated and way too expensive.',
  false
),
(
  'eeee5555-0000-0000-0000-000000000002',
  'aaaa1111-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000004',
  'I actually loved this place last month.',
  false
),
(
  'eeee5555-0000-0000-0000-000000000003',
  'aaaa1111-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000005',
  'The fish quality was good but the wait was brutal.',
  false
),
(
  'eeee5555-0000-0000-0000-000000000004',
  'aaaa1111-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000006',
  'Saving this for my next date night.',
  false
)
ON CONFLICT ("comment_Id") DO NOTHING;

-- Likes
INSERT INTO public."Likes" ("post_Id", "user_Id") VALUES
('aaaa1111-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001'),
('aaaa1111-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000004')
ON CONFLICT DO NOTHING;

-- Multiple reports on the same post
INSERT INTO public."Report" (
  "report_Id",
  "user_Id",
  "post_Id",
  "comment_Id",
  "reason",
  "details",
  "status",
  "created_At"
) VALUES
(
  'f1111111-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000003',
  'aaaa1111-0000-0000-0000-000000000000',
  null,
  'Harassment',
  'The discussion around this post became hostile.',
  0,
  now() - interval '3 hours'
),
(
  'f1111111-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000004',
  'aaaa1111-0000-0000-0000-000000000000',
  null,
  'Spam',
  'Looks repetitive and engagement-baity.',
  0,
  now() - interval '2 hours'
),
(
  'f1111111-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000005',
  'aaaa1111-0000-0000-0000-000000000000',
  null,
  'Misleading',
  'The description does not match the real experience.',
  0,
  now() - interval '90 minutes'
),

-- Multiple reports on one comment under that same post
(
  'f2222222-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  null,
  'eeee5555-0000-0000-0000-000000000001',
  'Abusive Language',
  'Comment is unnecessarily aggressive.',
  0,
  now() - interval '75 minutes'
),
(
  'f2222222-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000004',
  null,
  'eeee5555-0000-0000-0000-000000000001',
  'Harassment',
  'This targets the poster instead of the review.',
  0,
  now() - interval '45 minutes'
),
(
  'f2222222-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000006',
  null,
  'eeee5555-0000-0000-0000-000000000001',
  'Bullying',
  'The tone feels personal and hostile.',
  0,
  now() - interval '30 minutes'
),

-- Another reported comment on the same post
(
  'f2222222-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000003',
  null,
  'eeee5555-0000-0000-0000-000000000003',
  'Offensive Content',
  'This comment is too aggressive for a review thread.',
  0,
  now() - interval '20 minutes'
)
ON CONFLICT ("report_Id") DO NOTHING;
