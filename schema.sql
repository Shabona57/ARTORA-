-- ARTORA database setup for Supabase
-- Run this entire file in Supabase -> SQL Editor -> New query.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text,
  bio text default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.artworks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text default '',
  image_url text not null,
  category text not null default 'Painting',
  technique text,
  created_at timestamptz not null default now()
);

create table if not exists public.likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  artwork_id uuid not null references public.artworks(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, artwork_id)
);

create table if not exists public.saved_artworks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  artwork_id uuid not null references public.artworks(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, artwork_id)
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id <> following_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  artwork_id uuid not null references public.artworks(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  artwork_id uuid references public.artworks(id) on delete cascade,
  reason text not null,
  details text default '',
  status text not null default 'pending' check (status in ('pending','reviewed','resolved')),
  created_at timestamptz not null default now()
);

-- Automatically create a profile after a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  chosen_username text;
begin
  chosen_username := coalesce(
    nullif(new.raw_user_meta_data ->> 'username', ''),
    'artist_' || substr(new.id::text, 1, 8)
  );

  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    chosen_username,
    coalesce(new.raw_user_meta_data ->> 'display_name', chosen_username)
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Enable Row Level Security.
alter table public.profiles enable row level security;
alter table public.artworks enable row level security;
alter table public.likes enable row level security;
alter table public.saved_artworks enable row level security;
alter table public.follows enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;

-- Profiles: public read, owner update.
drop policy if exists "Profiles are publicly readable" on public.profiles;
create policy "Profiles are publicly readable"
on public.profiles for select using (true);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
on public.profiles for update to authenticated
using (auth.uid() = id) with check (auth.uid() = id);

-- Artworks: public read, authenticated owner insert/update/delete.
drop policy if exists "Artworks are publicly readable" on public.artworks;
create policy "Artworks are publicly readable"
on public.artworks for select using (true);

drop policy if exists "Users can create their own artworks" on public.artworks;
create policy "Users can create their own artworks"
on public.artworks for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Owners can update their artworks" on public.artworks;
create policy "Owners can update their artworks"
on public.artworks for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Owners can delete their artworks" on public.artworks;
create policy "Owners can delete their artworks"
on public.artworks for delete to authenticated
using (auth.uid() = user_id);

-- Likes: visible publicly; a user manages only their own likes.
drop policy if exists "Likes are publicly readable" on public.likes;
create policy "Likes are publicly readable"
on public.likes for select using (true);

drop policy if exists "Users can add their own likes" on public.likes;
create policy "Users can add their own likes"
on public.likes for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can remove their own likes" on public.likes;
create policy "Users can remove their own likes"
on public.likes for delete to authenticated
using (auth.uid() = user_id);

-- Saved artworks are private to their owner.
drop policy if exists "Users can view their own saved artworks" on public.saved_artworks;
create policy "Users can view their own saved artworks"
on public.saved_artworks for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can save artworks" on public.saved_artworks;
create policy "Users can save artworks"
on public.saved_artworks for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can unsave artworks" on public.saved_artworks;
create policy "Users can unsave artworks"
on public.saved_artworks for delete to authenticated
using (auth.uid() = user_id);

-- Follows: public read; users can follow/unfollow as themselves.
drop policy if exists "Follows are publicly readable" on public.follows;
create policy "Follows are publicly readable"
on public.follows for select using (true);

drop policy if exists "Users can follow as themselves" on public.follows;
create policy "Users can follow as themselves"
on public.follows for insert to authenticated
with check (auth.uid() = follower_id);

drop policy if exists "Users can unfollow as themselves" on public.follows;
create policy "Users can unfollow as themselves"
on public.follows for delete to authenticated
using (auth.uid() = follower_id);

-- Comments: public read; signed-in users can create/delete their own.
drop policy if exists "Comments are publicly readable" on public.comments;
create policy "Comments are publicly readable"
on public.comments for select using (true);

drop policy if exists "Authenticated users can comment" on public.comments;
create policy "Authenticated users can comment"
on public.comments for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own comments" on public.comments;
create policy "Users can delete their own comments"
on public.comments for delete to authenticated
using (auth.uid() = user_id);

-- Reports: a user can submit and view only their own reports.
drop policy if exists "Users can submit reports" on public.reports;
create policy "Users can submit reports"
on public.reports for insert to authenticated
with check (auth.uid() = reporter_id);

drop policy if exists "Users can view their own reports" on public.reports;
create policy "Users can view their own reports"
on public.reports for select to authenticated
using (auth.uid() = reporter_id);

-- Create a public bucket for artwork images.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('artwork-images', 'artwork-images', true, 10485760,
        array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Anyone can view public artwork images.
drop policy if exists "Artwork images are publicly viewable" on storage.objects;
create policy "Artwork images are publicly viewable"
on storage.objects for select
using (bucket_id = 'artwork-images');

-- Signed-in users can upload only into a folder named with their own user ID.
drop policy if exists "Users upload to their own artwork folder" on storage.objects;
create policy "Users upload to their own artwork folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'artwork-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users delete from their own artwork folder" on storage.objects;
create policy "Users delete from their own artwork folder"
on storage.objects for delete to authenticated
using (
  bucket_id = 'artwork-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);
