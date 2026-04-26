-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.Comment (
  comment_Id uuid NOT NULL,
  post_Id uuid,
  user_Id uuid,
  content text,
  created_At timestamp without time zone DEFAULT now(),
  isBlocked boolean NOT NULL DEFAULT false,
  CONSTRAINT Comment_pkey PRIMARY KEY (comment_Id),
  CONSTRAINT Comment_post_Id_fkey FOREIGN KEY (post_Id) REFERENCES public.Post(post_Id),
  CONSTRAINT Comment_user_Id_fkey FOREIGN KEY (user_Id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.Cuisine (
  type_id uuid NOT NULL DEFAULT gen_random_uuid(),
  desc text NOT NULL UNIQUE,
  isPrimaryOption boolean NOT NULL DEFAULT false,
  CONSTRAINT Cuisine_pkey PRIMARY KEY (type_id)
);
CREATE TABLE public.Follower (
  follower_Id uuid NOT NULL,
  following_Id uuid NOT NULL,
  created_At timestamp without time zone DEFAULT now(),
  CONSTRAINT Follower_pkey PRIMARY KEY (follower_Id, following_Id),
  CONSTRAINT Follower_follower_Id_fkey FOREIGN KEY (follower_Id) REFERENCES public.User(user_Id),
  CONSTRAINT Follower_following_Id_fkey FOREIGN KEY (following_Id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.Likes (
  post_Id uuid NOT NULL,
  user_Id uuid NOT NULL,
  created_At timestamp without time zone DEFAULT now(),
  CONSTRAINT Likes_pkey PRIMARY KEY (post_Id, user_Id),
  CONSTRAINT Likes_post_Id_fkey FOREIGN KEY (post_Id) REFERENCES public.Post(post_Id),
  CONSTRAINT Likes_user_Id_fkey FOREIGN KEY (user_Id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.Notification (
  id uuid NOT NULL,
  user_id uuid,
  content text,
  redirect_To text,
  created_At timestamp without time zone DEFAULT now(),
  isRead boolean NOT NULL DEFAULT false,
  sender_id uuid DEFAULT auth.uid(),
  CONSTRAINT Notification_pkey PRIMARY KEY (id),
  CONSTRAINT Notification_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.User(user_Id),
  CONSTRAINT Notification_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.Notification_Settings (
  settings_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  likes boolean NOT NULL DEFAULT true,
  comments boolean NOT NULL DEFAULT true,
  followers boolean NOT NULL DEFAULT true,
  mentions boolean NOT NULL DEFAULT true,
  push boolean NOT NULL DEFAULT true,
  inApp boolean NOT NULL DEFAULT true,
  CONSTRAINT Notification_Settings_pkey PRIMARY KEY (settings_id),
  CONSTRAINT notification_settings_user_fk FOREIGN KEY (user_id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.Post (
  post_Id uuid NOT NULL,
  user_Id uuid,
  restaurant_Id uuid,
  caption text,
  created_At timestamp without time zone DEFAULT now(),
  updated_At timestamp without time zone,
  likeCount integer DEFAULT 0,
  saveCount integer DEFAULT 0,
  isRemoved boolean DEFAULT false,
  title text,
  isBlocked boolean NOT NULL DEFAULT false,
  isPending boolean NOT NULL DEFAULT false,
  restaurant_approval_id uuid,
  visible_to_owner boolean NOT NULL DEFAULT true,
  CONSTRAINT Post_pkey PRIMARY KEY (post_Id),
  CONSTRAINT Post_user_Id_fkey FOREIGN KEY (user_Id) REFERENCES public.User(user_Id),
  CONSTRAINT Post_restaurant_Id_fkey FOREIGN KEY (restaurant_Id) REFERENCES public.Restaurant(restaurant_Id),
  CONSTRAINT Post_restaurant_approval_id_fkey FOREIGN KEY (restaurant_approval_id) REFERENCES public.RestaurantApproval(approval_Id)
);
CREATE TABLE public.Post_Image (
  image_Id uuid NOT NULL,
  post_Id uuid,
  image_url text,
  CONSTRAINT Post_Image_pkey PRIMARY KEY (image_Id),
  CONSTRAINT Post_Image_post_Id_fkey FOREIGN KEY (post_Id) REFERENCES public.Post(post_Id)
);
CREATE TABLE public.Reply (
  reply_Id uuid NOT NULL,
  comment_Id uuid,
  user_Id uuid,
  content text,
  created_At timestamp without time zone DEFAULT now(),
  CONSTRAINT Reply_pkey PRIMARY KEY (reply_Id),
  CONSTRAINT Reply_comment_Id_fkey FOREIGN KEY (comment_Id) REFERENCES public.Comment(comment_Id),
  CONSTRAINT Reply_user_Id_fkey FOREIGN KEY (user_Id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.Report (
  report_Id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_Id uuid NOT NULL,
  post_Id uuid,
  comment_Id uuid,
  reason text NOT NULL,
  status integer NOT NULL DEFAULT 0,
  created_At timestamp with time zone NOT NULL DEFAULT now(),
  details text,
  CONSTRAINT Report_pkey PRIMARY KEY (report_Id),
  CONSTRAINT Report_user_fkey FOREIGN KEY (user_Id) REFERENCES public.User(user_Id),
  CONSTRAINT Report_post_fkey FOREIGN KEY (post_Id) REFERENCES public.Post(post_Id),
  CONSTRAINT Report_comment_fkey FOREIGN KEY (comment_Id) REFERENCES public.Comment(comment_Id),
  CONSTRAINT Report_user_Id_fkey FOREIGN KEY (user_Id) REFERENCES public.User(user_Id),
  CONSTRAINT Report_post_Id_fkey FOREIGN KEY (post_Id) REFERENCES public.Post(post_Id),
  CONSTRAINT Report_comment_Id_fkey FOREIGN KEY (comment_Id) REFERENCES public.Comment(comment_Id),
  CONSTRAINT report_user_fk FOREIGN KEY (user_Id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.Restaurant (
  restaurant_Id uuid NOT NULL,
  restaurant_name text,
  address text,
  latitude double precision,
  longitude double precision,
  maps_url text,
  created_At timestamp without time zone DEFAULT now(),
  main_cuisine_id uuid,
  source text,
  info_url text,
  isDisabled boolean NOT NULL DEFAULT false,
  rating real,
  description text,
  price_range text,
  place_id text UNIQUE,
  CONSTRAINT Restaurant_pkey PRIMARY KEY (restaurant_Id),
  CONSTRAINT restaurant_main_cuisine_fk FOREIGN KEY (main_cuisine_id) REFERENCES public.Cuisine(type_id)
);
CREATE TABLE public.RestaurantApproval (
  approval_Id uuid NOT NULL,
  curr_restaurant_id uuid,
  restaurant_name text,
  address text,
  latitude double precision,
  longitude double precision,
  maps_url text,
  source text,
  status integer NOT NULL DEFAULT 0,
  detectedAt timestamp without time zone DEFAULT now(),
  main_cuisine_id uuid,
  rating real,
  image_url text,
  description text,
  price_range text,
  place_id text,
  CONSTRAINT RestaurantApproval_pkey PRIMARY KEY (approval_Id),
  CONSTRAINT restaurant_approval_curr_restaurant_fk FOREIGN KEY (curr_restaurant_id) REFERENCES public.Restaurant(restaurant_Id),
  CONSTRAINT restaurant_approval_main_cuisine_fk FOREIGN KEY (main_cuisine_id) REFERENCES public.Cuisine(type_id)
);
CREATE TABLE public.Restaurant_Cuisine (
  RestaurantId uuid NOT NULL,
  CuisineId uuid NOT NULL,
  CONSTRAINT Restaurant_Cuisine_pkey PRIMARY KEY (RestaurantId, CuisineId),
  CONSTRAINT restaurant_cuisine_restaurant_fk FOREIGN KEY (RestaurantId) REFERENCES public.Restaurant(restaurant_Id),
  CONSTRAINT restaurant_cuisine_cuisine_fk FOREIGN KEY (CuisineId) REFERENCES public.Cuisine(type_id)
);
CREATE TABLE public.Restaurant_Image (
  image_id uuid NOT NULL DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL DEFAULT gen_random_uuid(),
  image_url text,
  isCover boolean DEFAULT false,
  CONSTRAINT Restaurant_Image_pkey PRIMARY KEY (image_id),
  CONSTRAINT Restaurant_Image_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.Restaurant(restaurant_Id)
);
CREATE TABLE public.User (
  user_Id uuid NOT NULL,
  name text,
  bio text CHECK (length(bio) < 100),
  created_At timestamp without time zone DEFAULT now(),
  password text NOT NULL DEFAULT ''::text,
  role character varying NOT NULL DEFAULT 'user'::character varying CHECK (role::text = ANY (ARRAY['user'::character varying, 'admin'::character varying]::text[])),
  username text NOT NULL DEFAULT ''::text UNIQUE,
  CONSTRAINT User_pkey PRIMARY KEY (user_Id)
);
CREATE TABLE public.UserImage (
  image_id uuid NOT NULL,
  user_Id uuid,
  image_url text DEFAULT ''::text,
  CONSTRAINT UserImage_pkey PRIMARY KEY (image_id),
  CONSTRAINT UserImage_user_Id_fkey FOREIGN KEY (user_Id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.collections (
  collection_Id uuid NOT NULL,
  user_Id uuid,
  name text,
  description text,
  is_public boolean DEFAULT true,
  created_At timestamp without time zone DEFAULT now(),
  collection_type text NOT NULL DEFAULT '''POST''::text'::text CHECK (collection_type = ANY (ARRAY['POST'::text, 'RESTAURANT'::text])),
  is_default boolean NOT NULL DEFAULT false,
  CONSTRAINT collections_pkey PRIMARY KEY (collection_Id),
  CONSTRAINT collections_user_Id_fkey FOREIGN KEY (user_Id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.collections_item (
  item_Id uuid NOT NULL DEFAULT gen_random_uuid(),
  collection_Id uuid NOT NULL,
  restaurant_id uuid,
  post_id uuid,
  savedAt timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT collections_item_pkey PRIMARY KEY (item_Id),
  CONSTRAINT collections_item_collection_fk FOREIGN KEY (collection_Id) REFERENCES public.collections(collection_Id),
  CONSTRAINT collections_item_restaurant_fk FOREIGN KEY (restaurant_id) REFERENCES public.Restaurant(restaurant_Id),
  CONSTRAINT collections_item_post_fk FOREIGN KEY (post_id) REFERENCES public.Post(post_Id)
);
CREATE TABLE public.collections_shares (
  collection_Id uuid NOT NULL,
  share_with_id uuid NOT NULL,
  CONSTRAINT collections_shares_pkey PRIMARY KEY (collection_Id, share_with_id),
  CONSTRAINT collections_shares_collection_Id_fkey FOREIGN KEY (collection_Id) REFERENCES public.collections(collection_Id),
  CONSTRAINT collections_shares_share_with_id_fkey FOREIGN KEY (share_with_id) REFERENCES public.User(user_Id)
);
CREATE TABLE public.hashtag (
  hashtag_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  CONSTRAINT hashtag_pkey PRIMARY KEY (hashtag_id)
);
CREATE TABLE public.post_hashtag (
  post_Id uuid NOT NULL,
  hashtag_id uuid NOT NULL,
  CONSTRAINT post_hashtag_pkey PRIMARY KEY (post_Id, hashtag_id),
  CONSTRAINT post_hashtag_post_fk FOREIGN KEY (post_Id) REFERENCES public.Post(post_Id),
  CONSTRAINT post_hashtag_hashtag_fk FOREIGN KEY (hashtag_id) REFERENCES public.hashtag(hashtag_id)
);
CREATE TABLE public.swipe_history (
  user_id uuid NOT NULL,
  restaurant_id uuid NOT NULL,
  swiped_at timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT swipe_history_pkey PRIMARY KEY (user_id, restaurant_id, swiped_at),
  CONSTRAINT swipe_history_user_fk FOREIGN KEY (user_id) REFERENCES public.User(user_Id),
  CONSTRAINT swipe_history_restaurant_fk FOREIGN KEY (restaurant_id) REFERENCES public.Restaurant(restaurant_Id)
);