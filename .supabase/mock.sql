-- ============================================================
-- SEED DATA for taste_spot
-- Uses actual table names from your Supabase DB.
-- Run in Supabase SQL Editor.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ──────────────────────────────────────────────────────────
-- 1. USERS (10 users)
-- ──────────────────────────────────────────────────────────
INSERT INTO "User" ("user_Id", "name", "bio", "created_At") VALUES
  ('00000000-0000-0000-0000-000000000001', 'Sarah Lim',    'Food explorer 🍜 | KL-based foodie | Ramen addict',               NOW()),
  ('00000000-0000-0000-0000-000000000002', 'Ahmad Razif',  'Weekend warrior chef 🔥 | Hawker stall hunter',                   NOW()),
  ('00000000-0000-0000-0000-000000000003', 'Mei Ling Tan', 'Dessert queen 🍰 | Café hopper | Penang girl in KL',              NOW()),
  ('00000000-0000-0000-0000-000000000004', 'Raj Krishnan', 'Certified nasi lemak judge 🍛 | 10 years of eating well',         NOW()),
  ('00000000-0000-0000-0000-000000000005', 'Liyana Omar',  'Plant-based foodie 🌱 | Sustainability advocate',                 NOW()),
  ('00000000-0000-0000-0000-000000000006', 'Kevin Wong',   'Sushi snob 🍣 | Fine dining when the pay cheque hits',            NOW()),
  ('00000000-0000-0000-0000-000000000007', 'Nurul Ain',    'Kopitiam regular ☕ | Old town food ambassador',                   NOW()),
  ('00000000-0000-0000-0000-000000000008', 'Daniel Chong', 'BBQ evangelist 🥩 | Weekend grill master | Always hungry',        NOW()),
  ('00000000-0000-0000-0000-000000000009', 'Priya Nair',   'South Indian comfort food lover 🌶️ | Banana leaf every Friday',  NOW()),
  ('00000000-0000-0000-0000-000000000010', 'Zack Hamdan',  'Street food documentarian 📸 | If it has a queue, I''m in',      NOW());


-- ──────────────────────────────────────────────────────────
-- 2. RESTAURANTS (15 spots)
--    Note: your schema uses "longtitude" (typo) — matched here
-- ──────────────────────────────────────────────────────────
INSERT INTO "Restaurant" ("restaurant_Id", "restaurant_name", "address", "latitude", "longtitude", "categoryCuisine") VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Ichiban Ramen',       'Lot 10, Jalan Bukit Bintang, 55100 KL',        3.1478,  101.7131, 'Japanese'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'Nasi Kandar Pelita',  '149 Jalan Ampang, 50450 KL',                   3.1569,  101.7196, 'Malaysian'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'Plan B KLCC',         'KLCC Suria, Jalan Ampang, 50088 KL',           3.1578,  101.7119, 'Western'),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'Madam Kwan''s',       'KLCC Suria Level 4, 50088 KL',                 3.1579,  101.7118, 'Malaysian'),
  ('aaaaaaaa-0000-0000-0000-000000000005', 'Limapulo',            '50A Jalan Doraisamy, 50480 KL',                3.1624,  101.6995, 'Nyonya'),
  ('aaaaaaaa-0000-0000-0000-000000000006', 'The Alley',           'Pavilion KL, 168 Jalan Bukit Bintang, 55100',  3.1492,  101.7126, 'Bubble Tea'),
  ('aaaaaaaa-0000-0000-0000-000000000007', 'Sushi King',          'Mid Valley Megamall, 58000 KL',                3.1177,  101.6764, 'Japanese'),
  ('aaaaaaaa-0000-0000-0000-000000000008', 'Little Penang Kafe',  'KLCC Suria, 50088 KL',                         3.1576,  101.7117, 'Penang'),
  ('aaaaaaaa-0000-0000-0000-000000000009', 'Absolute Thai',       'The Gardens Mall, Mid Valley, 59200 KL',       3.1182,  101.6771, 'Thai'),
  ('aaaaaaaa-0000-0000-0000-000000000010', 'Chinoz on the Park',  'KLCC Park, 50088 KL',                          3.1581,  101.7112, 'Western'),
  ('aaaaaaaa-0000-0000-0000-000000000011', 'Jalan Alor Hawkers',  'Jalan Alor, Bukit Bintang, 50200 KL',          3.1459,  101.7092, 'Hawker'),
  ('aaaaaaaa-0000-0000-0000-000000000012', 'Devi''s Corner',      'Jalan Telawi 2, Bangsar, 59100 KL',            3.1295,  101.6724, 'Indian'),
  ('aaaaaaaa-0000-0000-0000-000000000013', 'Ben''s KL',           'KLCC Suria, Level 2, 50088 KL',                3.1577,  101.7120, 'Western'),
  ('aaaaaaaa-0000-0000-0000-000000000014', 'Rebung Chef Ismail',  'Hotel Istana, 73 Jalan Raja Chulan, 50200 KL', 3.1518,  101.7095, 'Malaysian'),
  ('aaaaaaaa-0000-0000-0000-000000000015', 'Sangkaya',            'Bangsar Shopping Centre, 59100 KL',            3.1301,  101.6728, 'Dessert');


-- ──────────────────────────────────────────────────────────
-- 3. POSTS (30 posts)
-- ──────────────────────────────────────────────────────────
INSERT INTO "Post" ("post_Id", "user_Id", "restaurant_Id", "caption", "likeCount", "saveCount", "isRemoved", "created_At") VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'This tonkotsu broth literally changed my life 🍜 Rich, creamy and the chashu just melts in your mouth!',          1204, 389, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002', 'Nasi kandar at 2am hits different 🌙 The dhal curry here is legendary. Been coming for 10 years!',               876, 214, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000015', 'Coconut ice cream on a fresh coconut 🥥 Peak dessert life. The gula melaka topping is chef''s kiss.',           3412, 902, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000004', 'Nasi lemak royale 🍛 Madam Kwan''s never misses. Must-visit for tourists AND locals alike.',                     654, 178, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000005', 'Nyonya laksa with 10/10 sambal tumis 🌶️ Limapulo has the most authentic Peranakan flavours in KL.',           2891, 743, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000007', 'Salmon aburi platter 🔥 When the blowtorch hits that salmon the whole restaurant smells amazing!',               421,  99, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000008', 'Char kuey teow outside Penang done RIGHT 🍳 The wok hei is real. Old town auntie vibes but in KL.',           5203, 1482, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000008', 'aaaaaaaa-0000-0000-0000-000000000011', 'Whole roast chicken on Jalan Alor 🐓 RM35 for this beauty. Skin is perfectly crispy, garlic sauce unreal.',     998, 267, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000012', 'Banana leaf rice Friday 🍌 Seven curries, unlimited rice, papadom. Life is good at Devi''s Corner.',          1783, 511, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000010', 'aaaaaaaa-0000-0000-0000-000000000014', 'Traditional kampung feast at Rebung 🌿 60+ dishes of pure Malaysian heritage food. Mind blown.',              2340, 628, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', 'Brunch goals ✨ Plan B''s eggs benedict with smoked salmon. Hollandaise is silky smooth.',                      732, 201, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000009', 'Pad thai with tiger prawns 🦐 Absolute Thai never disappoints. Perfect tamarind balance.',                      567, 145, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000006', 'Brown sugar tiger milk tea ☕🐯 The Alley is life. That caramelised drizzle hits every single time.',           1890, 512, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000014', '00000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000010', 'Lakeside breakfast with the best view in KL 🌅 Chinoz is pricey but the ambiance is unmatched.',               445, 134, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000015', '00000000-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000005', 'Ayam buah keluak — Peranakan perfection 🖤 This dish takes 3 days to prepare and you taste every hour.',       3120, 880, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000016', '00000000-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', 'Spicy miso ramen 🌶️🍜 Level 6/10 and I''m sweating but I can''t stop. The jammy egg is perfect.',              880, 220, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000017', '00000000-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000002', 'Roti canai at sunrise 🌄 There''s something magical about mamak breakfast before the city wakes up.',          2100, 678, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000018', '00000000-0000-0000-0000-000000000008', 'aaaaaaaa-0000-0000-0000-000000000011', 'Oyster omelette from Jalan Alor 🦪 Crispy edges, gooey inside, fresh oysters. Stall since 1978!',            1560, 430, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000019', '00000000-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000012', 'Mutton varuval — crispy, spiced, perfection 🥩 Curry leaf fragrance fills the whole corner of Bangsar.',       920, 288, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000020', '00000000-0000-0000-0000-000000000010', 'aaaaaaaa-0000-0000-0000-000000000013', 'Truffle mac from Ben''s 🧀 Most indulgent lunch of my week. Crispy breadcrumb topping is the move.',           671, 189, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000008', 'Assam laksa with thick rice noodles 🎣 Only place in KL I trust for real Penang assam laksa.',               1340, 376, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000022', '00000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000004', 'Rendang tok SO rich and dark 🤎 The coconut kerisik caramelisation is on another level. Best in KV.',         1780, 492, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000023', '00000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000015', 'Cendol with gula melaka 💚 Sangkaya''s cendol is refreshing AF on a 35°C KL day.',                           2450, 701, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000024', '00000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000014', 'Sayur lodeh with tempeh 🥬 Chef Ismail''s buffet has dishes my grandma used to make. Pure nostalgia.',         560, 155, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000025', '00000000-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000003', 'Vegan mushroom burger 🍄 Plan B does plant-based right. Portobello patty + truffle aioli is insane.',          890, 245, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000026', '00000000-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000007', 'Unagi don — grilled eel on rice 🥢 Sushi King''s unagi is underrated. Sweet soy glaze, generous portion.',    430, 112, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000027', '00000000-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000002', '2am hunger cured by murtabak 🥚 Flaky, crispy layers with minced meat — absolutely worth the wait.',          1120, 315, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000028', '00000000-0000-0000-0000-000000000008', 'aaaaaaaa-0000-0000-0000-000000000011', 'Satay 20 sticks for RM18 🥜 Jalan Alor night market with peanut sauce and ketupat. Budget feast!',           2890, 810, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000029', '00000000-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000009', 'Green curry with roti 🌿 Absolute Thai''s base is herbaceous and coconutty. Could drink this as soup.',        770, 211, FALSE, NOW()),
  ('bbbbbbbb-0000-0000-0000-000000000030', '00000000-0000-0000-0000-000000000010', 'aaaaaaaa-0000-0000-0000-000000000010', 'Afternoon hi-tea with KLCC view ☁️ Chinoz on the Park is the ultimate flex. Scones with clotted cream 10/10.', 3300, 945, FALSE, NOW());


-- ──────────────────────────────────────────────────────────
-- 4. COMMENTS (30 comments)
-- ──────────────────────────────────────────────────────────
INSERT INTO "Comment" ("comment_Id", "post_Id", "user_Id", "content", "created_At") VALUES
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Just went last night, queue was 45 mins but SO worth it! 🔥',          NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'What''s the price range? Looks expensive but amazing 😍',               NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'The tonkotsu here beats some places I tried in Japan 👀',               NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000005', 'Pelita is an institution. Been eating here since uni days ❤️',         NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000006', 'The fish head curry here is also incredible if you haven''t tried!',   NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'Sangkaya is my fav dessert stop in all of KL! 🥥',                     NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000008', 'Madam Kwan''s beef rendang is also a must order! Don''t skip it.',     NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000009', 'Limapulo is criminally underrated. Most people don''t know about it!', NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000002', 'Char kuey teow at Little Penang is the real deal 👏',                  NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000003', 'The wok hei smell fills the whole floor 😂',                           NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000004', 'Jalan Alor roast chicken is iconic. Been here since std 6!',           NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000005', 'Seven curries at Devi''s with unlimited rice is buffet king 👑',       NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000006', 'Rebung is a national treasure. Traditions preserved beautifully 🙏',  NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000007', 'The ambiance is so warm. Like Sunday lunch at tok''s house.',          NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000009', 'Brown sugar hits different when it''s fresh! Don''t let it melt.',    NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000015', '00000000-0000-0000-0000-000000000010', 'Ayam buah keluak is the most complex dish in SEA cuisine.',           NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000017', '00000000-0000-0000-0000-000000000001', 'Mamak roti canai sunrise is spiritual. Every Saturday for me 🌅',     NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000018', '00000000-0000-0000-0000-000000000002', 'That 1978 oyster omelette stall is legendary!',                       NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000019', '00000000-0000-0000-0000-000000000003', 'Mutton varuval + plain rice is all you need in life.',                NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000020', '00000000-0000-0000-0000-000000000004', 'Ben''s truffle mac is overpriced but I keep going back. That''s truffle power.', NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000023', '00000000-0000-0000-0000-000000000007', 'Cendol on a hot day is the ultimate Malaysian stress reliever 💚',   NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000025', '00000000-0000-0000-0000-000000000008', 'Plan B vegan burger converted my meat-eating friend. Impressive.',    NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000028', '00000000-0000-0000-0000-000000000010', 'RM18 for 20 sticks — best value street food in KL. Always has been.', NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000030', '00000000-0000-0000-0000-000000000003', 'Chinoz KLCC view never gets old. Perfect for impressing clients 😏',  NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000010', 'Did you try the karaage chicken side? It''s addictive with ramen!',   NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000016', '00000000-0000-0000-0000-000000000005', 'Spicy miso level 8 is where I blackout 😵',                           NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000026', '00000000-0000-0000-0000-000000000007', 'Unagi don is so slept on at Sushi King! Better than chirashi.',       NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000008', 'Absolute Thai pad thai is sweeter than Bangkok-style but top tier!', NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000029', '00000000-0000-0000-0000-000000000002', 'Green curry + roti is an underrated combo. Herb + Asian bread = 💥',  NOW()),
  (uuid_generate_v4(), 'bbbbbbbb-0000-0000-0000-000000000022', '00000000-0000-0000-0000-000000000006', 'Rendang tok vs rendang padang... both amazing but different souls.',  NOW());


-- ──────────────────────────────────────────────────────────
-- 5. COLLECTIONS
-- ──────────────────────────────────────────────────────────
INSERT INTO "collections" ("collection_Id", "user_Id", "name", "description", "is_public", "created_At") VALUES
  ('cccccccc-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Ramen Bucket List',   'Every ramen spot I want to try in KL',        TRUE,  NOW()),
  ('cccccccc-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Late Night Eats',     'Best spots open past midnight in KL',         TRUE,  NOW()),
  ('cccccccc-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 'Dessert Diary',       'My sweet journey across KL cafes',            TRUE,  NOW()),
  ('cccccccc-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', 'Malaysian Heritage',  'Traditional Malaysian food worth preserving',  FALSE, NOW()),
  ('cccccccc-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', 'Plant Based KL',      'Best vegan and vegetarian spots in KL',       TRUE,  NOW());

INSERT INTO "collections_post" ("collection_Id", "post_Id", "saved_At") VALUES
  ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', NOW()),
  ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000016', NOW()),
  ('cccccccc-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', NOW()),
  ('cccccccc-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000017', NOW()),
  ('cccccccc-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000027', NOW()),
  ('cccccccc-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000003', NOW()),
  ('cccccccc-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000013', NOW()),
  ('cccccccc-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000023', NOW()),
  ('cccccccc-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000010', NOW()),
  ('cccccccc-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000022', NOW()),
  ('cccccccc-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000025', NOW());


-- ──────────────────────────────────────────────────────────
-- 6. RESTAURANT APPROVALS (sample pending submissions)
-- ──────────────────────────────────────────────────────────
INSERT INTO "RestaurantApproval" ("approval_Id", "restaurant_name", "address", "category_cuisine") VALUES
  (uuid_generate_v4(), 'Kedai Makan Pak Ali',  '12 Lorong Haji Taib, Chow Kit, 50350 KL', 'Malaysian'),
  (uuid_generate_v4(), 'Ramen Tora',           '23 Jalan SS2/24, Petaling Jaya, 47500',   'Japanese'),
  (uuid_generate_v4(), 'Pho Saigon House',     '8 Jalan Tun Razak, 50400 KL',             'Vietnamese');
