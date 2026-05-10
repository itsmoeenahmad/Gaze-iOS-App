-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.blocked_users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  blocker_id uuid NOT NULL,
  blocked_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT blocked_users_pkey PRIMARY KEY (id),
  CONSTRAINT blocked_users_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT blocked_users_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT blocked_users_unique UNIQUE (blocker_id, blocked_id),
  CONSTRAINT blocked_users_no_self_block CHECK (blocker_id <> blocked_id)
);
CREATE TABLE public.challenge_daily_finalists (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL,
  submission_id uuid NOT NULL,
  submission_day date NOT NULL,
  rank integer NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT challenge_daily_finalists_pkey PRIMARY KEY (id),
  CONSTRAINT challenge_daily_finalists_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.weekly_challenges(id),
  CONSTRAINT challenge_daily_finalists_submission_id_fkey FOREIGN KEY (submission_id) REFERENCES public.challenge_submissions(id)
);
CREATE TABLE public.challenge_entries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  week_number integer NOT NULL,
  year integer NOT NULL,
  user_id uuid NOT NULL,
  outfit_id uuid NOT NULL,
  vote_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT challenge_entries_pkey PRIMARY KEY (id),
  CONSTRAINT challenge_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT challenge_entries_outfit_id_fkey FOREIGN KEY (outfit_id) REFERENCES public.outfits(id)
);
CREATE TABLE public.challenge_finals_votes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL,
  submission_id uuid NOT NULL,
  voter_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT challenge_finals_votes_pkey PRIMARY KEY (id),
  CONSTRAINT challenge_finals_votes_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.weekly_challenges(id),
  CONSTRAINT challenge_finals_votes_submission_id_fkey FOREIGN KEY (submission_id) REFERENCES public.challenge_submissions(id),
  CONSTRAINT challenge_finals_votes_voter_id_fkey FOREIGN KEY (voter_id) REFERENCES auth.users(id)
);
CREATE TABLE public.challenge_submission_comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL,
  user_id uuid NOT NULL,
  body text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT challenge_submission_comments_pkey PRIMARY KEY (id),
  CONSTRAINT challenge_submission_comments_submission_id_fkey FOREIGN KEY (submission_id) REFERENCES public.challenge_submissions(id),
  CONSTRAINT challenge_submission_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.challenge_submission_likes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT challenge_submission_likes_pkey PRIMARY KEY (id),
  CONSTRAINT challenge_submission_likes_submission_id_fkey FOREIGN KEY (submission_id) REFERENCES public.challenge_submissions(id),
  CONSTRAINT challenge_submission_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.challenge_submission_votes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL,
  voter_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT challenge_submission_votes_pkey PRIMARY KEY (id),
  CONSTRAINT challenge_submission_votes_submission_id_fkey FOREIGN KEY (submission_id) REFERENCES public.challenge_submissions(id),
  CONSTRAINT challenge_submission_votes_voter_id_fkey FOREIGN KEY (voter_id) REFERENCES auth.users(id)
);
CREATE TABLE public.challenge_submissions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL,
  user_id uuid NOT NULL,
  image_url text NOT NULL,
  caption text,
  status USER-DEFINED NOT NULL DEFAULT 'pending'::submission_status,
  vote_count integer NOT NULL DEFAULT 0,
  like_count integer NOT NULL DEFAULT 0,
  comment_count integer NOT NULL DEFAULT 0,
  submission_day date,
  voting_window_start timestamp with time zone,
  voting_window_end timestamp with time zone,
  confirmed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT challenge_submissions_pkey PRIMARY KEY (id),
  CONSTRAINT challenge_submissions_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.weekly_challenges(id),
  CONSTRAINT challenge_submissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.challenge_votes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entry_id uuid NOT NULL,
  week_number integer NOT NULL,
  year integer NOT NULL,
  voter_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT challenge_votes_pkey PRIMARY KEY (id),
  CONSTRAINT challenge_votes_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.challenge_entries(id),
  CONSTRAINT challenge_votes_voter_id_fkey FOREIGN KEY (voter_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.challenge_winners (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL UNIQUE,
  submission_id uuid NOT NULL,
  winner_user_id uuid NOT NULL,
  winner_vote_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT challenge_winners_pkey PRIMARY KEY (id),
  CONSTRAINT challenge_winners_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.weekly_challenges(id),
  CONSTRAINT challenge_winners_submission_id_fkey FOREIGN KEY (submission_id) REFERENCES public.challenge_submissions(id),
  CONSTRAINT challenge_winners_winner_user_id_fkey FOREIGN KEY (winner_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.comment_likes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  comment_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT comment_likes_pkey PRIMARY KEY (id),
  CONSTRAINT comment_likes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id),
  CONSTRAINT comment_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  outfit_id uuid NOT NULL,
  user_id uuid NOT NULL,
  text text NOT NULL CHECK (char_length(text) > 0),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  like_count integer NOT NULL DEFAULT 0,
  CONSTRAINT comments_pkey PRIMARY KEY (id),
  CONSTRAINT comments_outfit_id_fkey FOREIGN KEY (outfit_id) REFERENCES public.outfits(id),
  CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.fires (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  outfit_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT fires_pkey PRIMARY KEY (id),
  CONSTRAINT fires_outfit_id_fkey FOREIGN KEY (outfit_id) REFERENCES public.outfits(id),
  CONSTRAINT fires_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.follows (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  follower_id uuid NOT NULL,
  following_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT follows_pkey PRIMARY KEY (id),
  CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.profiles(id),
  CONSTRAINT follows_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.friend_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  from_user_id uuid NOT NULL,
  to_user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT friend_requests_pkey PRIMARY KEY (id),
  CONSTRAINT friend_requests_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.profiles(id),
  CONSTRAINT friend_requests_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type text NOT NULL,
  from_user_id uuid,
  post_id uuid,
  message text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT notifications_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.outfits (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  image_url text,
  caption text NOT NULL DEFAULT ''::text,
  brands ARRAY NOT NULL DEFAULT '{}'::text[],
  style_category text NOT NULL DEFAULT 'Minimalist'::text,
  fire_count integer NOT NULL DEFAULT 0,
  comment_count integer NOT NULL DEFAULT 0,
  visibility text NOT NULL DEFAULT 'everyone'::text CHECK (visibility = ANY (ARRAY['everyone'::text, 'friends'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone,
  price_level integer NOT NULL DEFAULT 2 CHECK (price_level >= 1 AND price_level <= 4),
  link text,
  CONSTRAINT outfits_pkey PRIMARY KEY (id),
  CONSTRAINT outfits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text NOT NULL UNIQUE,
  display_name text NOT NULL DEFAULT ''::text,
  avatar_url text,
  bio text NOT NULL DEFAULT ''::text,
  city text NOT NULL DEFAULT ''::text,
  style_category text NOT NULL DEFAULT 'Minimalist'::text,
  follower_count integer NOT NULL DEFAULT 0,
  following_count integer NOT NULL DEFAULT 0,
  outfit_count integer NOT NULL DEFAULT 0,
  is_verified boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  challenge_wins integer NOT NULL DEFAULT 0,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.saved_outfits (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  outfit_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT saved_outfits_pkey PRIMARY KEY (id),
  CONSTRAINT saved_outfits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT saved_outfits_outfit_id_fkey FOREIGN KEY (outfit_id) REFERENCES public.outfits(id)
);
CREATE TABLE public.weekly_challenges (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  iso_week integer NOT NULL,
  iso_year integer NOT NULL,
  theme_name text NOT NULL,
  theme_emoji text NOT NULL DEFAULT '✨'::text,
  theme_description text NOT NULL DEFAULT ''::text,
  theme_gradient_start text NOT NULL DEFAULT '#2d1b69'::text,
  theme_gradient_end text NOT NULL DEFAULT '#5856D6'::text,
  status USER-DEFINED NOT NULL DEFAULT 'collecting'::challenge_status,
  starts_at timestamp with time zone NOT NULL,
  collecting_ends_at timestamp with time zone NOT NULL,
  finals_ends_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT weekly_challenges_pkey PRIMARY KEY (id)
);