-- ============================================================
-- GAZE — Full Supabase Schema
-- Paste this entire file into Supabase SQL Editor and run it.
-- ============================================================

-- 1. PROFILES (one row per auth user)
create table public.profiles (
  id              uuid references auth.users(id) on delete cascade primary key,
  username        text unique not null,
  display_name    text not null default '',
  avatar_url      text,
  bio             text not null default '',
  city            text not null default '',
  style_category  text not null default 'Minimalist',
  follower_count  int  not null default 0,
  following_count int  not null default 0,
  outfit_count    int  not null default 0,
  is_verified     boolean not null default false,
  created_at      timestamptz not null default now()
);

-- 2. OUTFITS
create table public.outfits (
  id             uuid not null default gen_random_uuid() primary key,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  image_url      text,
  caption        text not null default '',
  brands         text[] not null default '{}',
  style_category text not null default 'Minimalist',
  fire_count     int  not null default 0,
  comment_count  int  not null default 0,
  visibility     text not null default 'everyone' check (visibility in ('everyone','friends')),
  created_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

-- 3. FIRES (likes)
create table public.fires (
  id         uuid not null default gen_random_uuid() primary key,
  outfit_id  uuid not null references public.outfits(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (outfit_id, user_id)
);

-- 4. COMMENTS
create table public.comments (
  id         uuid not null default gen_random_uuid() primary key,
  outfit_id  uuid not null references public.outfits(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  text       text not null check (char_length(text) > 0),
  created_at timestamptz not null default now()
);

-- 5. FOLLOWS
create table public.follows (
  id           uuid not null default gen_random_uuid() primary key,
  follower_id  uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),
  unique (follower_id, following_id),
  check (follower_id <> following_id)
);

-- 6. SAVED OUTFITS
create table public.saved_outfits (
  id         uuid not null default gen_random_uuid() primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  outfit_id  uuid not null references public.outfits(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, outfit_id)
);

-- INDEXES
create index outfits_user_id_idx   on public.outfits(user_id);
create index outfits_created_idx   on public.outfits(created_at desc);
create index fires_outfit_idx      on public.fires(outfit_id);
create index follows_follower_idx  on public.follows(follower_id);
create index follows_following_idx on public.follows(following_id);
create index comments_outfit_idx   on public.comments(outfit_id);

-- ============================================================
-- TRIGGERS — auto-update counts
-- ============================================================

-- fire_count +/-
create or replace function public.trg_fire_inc()
returns trigger language plpgsql as $$
begin
  update public.outfits set fire_count = fire_count + 1 where id = new.outfit_id;
  return new;
end; $$;
create trigger after_fire_insert after insert on public.fires
  for each row execute function public.trg_fire_inc();

create or replace function public.trg_fire_dec()
returns trigger language plpgsql as $$
begin
  update public.outfits set fire_count = greatest(0, fire_count - 1) where id = old.outfit_id;
  return old;
end; $$;
create trigger after_fire_delete after delete on public.fires
  for each row execute function public.trg_fire_dec();

-- comment_count +
create or replace function public.trg_comment_inc()
returns trigger language plpgsql as $$
begin
  update public.outfits set comment_count = comment_count + 1 where id = new.outfit_id;
  return new;
end; $$;
create trigger after_comment_insert after insert on public.comments
  for each row execute function public.trg_comment_inc();

-- follower / following counts
create or replace function public.trg_follow_inc()
returns trigger language plpgsql as $$
begin
  update public.profiles set following_count = following_count + 1 where id = new.follower_id;
  update public.profiles set follower_count  = follower_count  + 1 where id = new.following_id;
  return new;
end; $$;
create trigger after_follow_insert after insert on public.follows
  for each row execute function public.trg_follow_inc();

create or replace function public.trg_follow_dec()
returns trigger language plpgsql as $$
begin
  update public.profiles set following_count = greatest(0, following_count - 1) where id = old.follower_id;
  update public.profiles set follower_count  = greatest(0, follower_count  - 1) where id = old.following_id;
  return old;
end; $$;
create trigger after_follow_delete after delete on public.follows
  for each row execute function public.trg_follow_dec();

-- outfit_count +
create or replace function public.trg_outfit_inc()
returns trigger language plpgsql as $$
begin
  update public.profiles set outfit_count = outfit_count + 1 where id = new.user_id;
  return new;
end; $$;
create trigger after_outfit_insert after insert on public.outfits
  for each row execute function public.trg_outfit_inc();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles      enable row level security;
alter table public.outfits       enable row level security;
alter table public.fires         enable row level security;
alter table public.comments      enable row level security;
alter table public.follows       enable row level security;
alter table public.saved_outfits enable row level security;

-- profiles
create policy "profiles_read"   on public.profiles for select using (true);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- outfits
create policy "outfits_read"   on public.outfits for select using (deleted_at is null);
create policy "outfits_insert" on public.outfits for insert with check (auth.uid() = user_id);
create policy "outfits_update" on public.outfits for update using (auth.uid() = user_id);
create policy "outfits_delete" on public.outfits for delete using (auth.uid() = user_id);

-- fires
create policy "fires_read"   on public.fires for select using (true);
create policy "fires_insert" on public.fires for insert with check (auth.uid() = user_id);
create policy "fires_delete" on public.fires for delete using (auth.uid() = user_id);

-- comments
create policy "comments_read"   on public.comments for select using (true);
create policy "comments_insert" on public.comments for insert with check (auth.uid() = user_id);
create policy "comments_delete" on public.comments for delete using (auth.uid() = user_id);

-- follows
create policy "follows_read"   on public.follows for select using (true);
create policy "follows_insert" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on public.follows for delete using (auth.uid() = follower_id);

-- saved_outfits (private — only owner)
create policy "saved_read"   on public.saved_outfits for select using (auth.uid() = user_id);
create policy "saved_insert" on public.saved_outfits for insert with check (auth.uid() = user_id);
create policy "saved_delete" on public.saved_outfits for delete using (auth.uid() = user_id);
