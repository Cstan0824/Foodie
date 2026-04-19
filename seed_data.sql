-- Insert Test Users (Specifically including the hardcoded test user)
INSERT INTO public."User" ("user_Id", "name", "bio") VALUES
('00000000-0000-0000-0000-000000000001', 'Test User', 'This is the hardcoded test user.'),
('00000000-0000-0000-0000-000000000002', 'Alice Smith', 'Food blogger based in NY.'),
('00000000-0000-0000-0000-000000000003', 'Bob Jones', 'Loves spicy food and coffee.')
ON CONFLICT ("user_Id") DO NOTHING;

-- Insert Restaurants
INSERT INTO public."Restaurant" ("restaurant_Id", "restaurant_name", "categoryCuisine", "address") VALUES
('11111111-1111-1111-1111-111111111111', 'Sakura Sushi Bar', 'Japanese', '123 Main St, NY'),
('22222222-2222-2222-2222-222222222222', 'The Burger Lab', 'American', '456 Elm St, NY'),
('33333333-3333-3333-3333-333333333333', 'Cafe Mocha', 'Cafe', '789 Oak St, NY')
ON CONFLICT ("restaurant_Id") DO NOTHING;

-- Insert Posts
INSERT INTO public."Post" ("post_Id", "user_Id", "restaurant_Id", "title", "caption", "likeCount", "saveCount") VALUES
('aaaa1111-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Amazing Sushi!', 'The omakase here was incredible. Highly recommend.', 1, 0),
('bbbb2222-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'Best Burgers', 'Double cheeseburger with truffle fries is a must-try.', 0, 1),
('cccc3333-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'Morning Coffee', 'Starting my day with a perfect latte.', 0, 0)
ON CONFLICT ("post_Id") DO NOTHING;

-- Insert Post Images (using Unsplash placeholders)
INSERT INTO public."Post_Image" ("image_Id", "post_Id", "image_url") VALUES
('dddd4444-0000-0000-0000-000000000001', 'aaaa1111-0000-0000-0000-000000000000', 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=800'),
('dddd4444-0000-0000-0000-000000000002', 'aaaa1111-0000-0000-0000-000000000000', 'https://images.unsplash.com/photo-1553621042-f6e147245754?q=80&w=800'),
('dddd4444-0000-0000-0000-000000000003', 'bbbb2222-0000-0000-0000-000000000000', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=800'),
('dddd4444-0000-0000-0000-000000000004', 'cccc3333-0000-0000-0000-000000000000', 'https://images.unsplash.com/photo-1521017432531-fbd92d768814?q=80&w=800')
ON CONFLICT ("image_Id") DO NOTHING;

-- Insert Comments
INSERT INTO public."Comment" ("comment_Id", "post_Id", "user_Id", "content") VALUES
('eeee5555-0000-0000-0000-000000000001', 'aaaa1111-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000003', 'Wow, that looks so fresh!'),
('eeee5555-0000-0000-0000-000000000002', 'bbbb2222-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001', 'I need to go here this weekend.')
ON CONFLICT ("comment_Id") DO NOTHING;

-- Insert Likes
INSERT INTO public."Likes" ("post_Id", "user_Id") VALUES
('aaaa1111-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

-- Insert Saves
INSERT INTO public."Saved" ("post_Id", "user_Id") VALUES
('bbbb2222-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;
