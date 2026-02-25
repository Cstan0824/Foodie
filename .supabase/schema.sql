-- Recommended (usually already enabled on Supabase)
create extension if not exists "pgcrypto";

-- =========================================================
-- 1) PROFILES (your "User" table)
-- =========================================================
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  bio text,
  created_at timestamp not null default now()
);

-- Optional: profile image (your "UserImage" table)
-- NOTE: For production, better store image in Supabase Storage and keep URL here.
create table if not exists public.user_image (
  image_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  profile_image bytea,
  created_at timestamp not null default now()
);

create index if not exists idx_user_image_user_id on public.user_image(user_id);


-- =========================================================
-- 2) RESTAURANT + APPROVAL
-- =========================================================
create table if not exists public.restaurant (
  restaurant_id uuid primary key default gen_random_uuid(),
  restaurant_name text not null,
  address text,
  latitude double precision,
  longitude double precision,
  category_cuisine text,
  maps_url text,
  created_at timestamp not null default now()
);

-- approval records (your RestaurantApproval)
create table if not exists public.restaurant_approval (
  approval_id uuid primary key default gen_random_uuid(),
  -- "crm_restaurant_id" in your diagram: keep nullable if it's "pending new restaurant"
  crm_restaurant_id uuid references public.restaurant(restaurant_id) on delete set null,
  restaurant_name text not null,
  address text,
  latitude double precision,
  longitude double precision,
  category_cuisine text,
  maps_url text,
  created_at timestamp not null default now()
);


-- =========================================================
-- 3) POST + POST IMAGE
-- =========================================================
create table if not exists public.post (
  post_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  restaurant_id uuid references public.restaurant(restaurant_id) on delete set null,
  caption text,
  created_at timestamp not null default now(),
  updated_at timestamp not null default now(),
  like_count integer not null default 0,
  save_count integer not null default 0,
  is_removed boolean not null default false
);

create index if not exists idx_post_user_id on public.post(user_id);
create index if not exists idx_post_restaurant_id on public.post(restaurant_id);

-- your Post_Image
create table if not exists public.post_image (
  image_id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.post(post_id) on delete cascade,
  images bytea,
  created_at timestamp not null default now()
);

create index if not exists idx_post_image_post_id on public.post_image(post_id);


-- =========================================================
-- 4) COMMENTS + REPLIES
-- =========================================================
create table if not exists public.comment (
  comment_id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.post(post_id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  content text not null,
  created_at timestamp not null default now()
);

create index if not exists idx_comment_post_id on public.comment(post_id);
create index if not exists idx_comment_user_id on public.comment(user_id);

create table if not exists public.reply (
  reply_id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comment(comment_id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  content text not null,
  created_at timestamp not null default now()
);

create index if not exists idx_reply_comment_id on public.reply(comment_id);
create index if not exists idx_reply_user_id on public.reply(user_id);


-- =========================================================
-- 5) LIKES + SAVED (junction tables)
-- =========================================================
create table if not exists public.likes (
  post_id uuid not null references public.post(post_id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamp not null default now(),
  primary key (post_id, user_id)
);

create index if not exists idx_likes_user_id on public.likes(user_id);

create table if not exists public.saved (
  post_id uuid not null references public.post(post_id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamp not null default now(),
  primary key (post_id, user_id)
);

create index if not exists idx_saved_user_id on public.saved(user_id);


-- =========================================================
-- 6) FOLLOWER (self-referencing junction)
-- =========================================================
create table if not exists public.follower (
  follower_id uuid not null references public.profiles(user_id) on delete cascade,
  following_id uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamp not null default now(),
  primary key (follower_id, following_id),
  constraint chk_not_follow_self check (follower_id <> following_id)
);

create index if not exists idx_follower_following_id on public.follower(following_id);


-- =========================================================
-- 7) COLLECTIONS + COLLECTIONS_POST + COLLECTIONS_SHARES
-- =========================================================
create table if not exists public.collections (
  collection_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  name text not null,
  description text,
  is_public boolean not null default false,
  created_at timestamp not null default now()
);

create index if not exists idx_collections_user_id on public.collections(user_id);

-- collections_post (many-to-many)
create table if not exists public.collections_post (
  collection_id uuid not null references public.collections(collection_id) on delete cascade,
  post_id uuid not null references public.post(post_id) on delete cascade,
  saved_at timestamp not null default now(),
  primary key (collection_id, post_id)
);

create index if not exists idx_col_post_post_id on public.collections_post(post_id);

-- collections_shares
create table if not exists public.collections_shares (
  collection_id uuid not null references public.collections(collection_id) on delete cascade,
  share_with_id uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamp not null default now(),
  primary key (collection_id, share_with_id)
);

create index if not exists idx_col_shares_share_with_id on public.collections_shares(share_with_id);


-- =========================================================
-- 8) NOTIFICATION
-- =========================================================
create table if not exists public.notification (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  content text not null,
  redirect_to text,
  created_at timestamp not null default now()
);

create index if not exists idx_notification_user_id on public.notification(user_id);