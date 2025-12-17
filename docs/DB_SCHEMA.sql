-- Calisthena MVP v1 DB Schema (SPEC)
-- This file is a blueprint to be applied to Supabase later (via migrations or SQL editor).

-- Extensions
create extension if not exists "pgcrypto";

-- =========================
-- Core: Profiles + Ratings
-- =========================

create table if not exists public.profiles (
  id uuid primary key, -- matches auth.users.id
  handle text unique,
  display_name text,
  bio text,
  country text,
  coach_personality text check (coach_personality in ('motivator','instructor','strict','custom')) default 'instructor',
  custom_style text,
  skill_focus text[] default '{}'::text[],
  level text,
  goals text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ratings_global (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  elo int not null default 1200,
  updated_at timestamptz not null default now()
);

create index if not exists idx_ratings_global_elo_desc on public.ratings_global (elo desc);

-- =========================
-- Skills + Pins
-- =========================

create table if not exists public.skills (
  id text primary key,
  name text not null,
  sort_order int not null
);

create table if not exists public.pins (
  id uuid primary key default gen_random_uuid(),
  skill_id text not null references public.skills(id) on delete cascade,
  code text not null unique,             -- e.g. planche_adv_tuck
  name text not null,                    -- e.g. Advanced Tuck
  level int not null,                    -- ordering within tree
  points int not null,                   -- contributes to Elo_v1
  ai_threshold int not null default 70,  -- stub threshold for MVP
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_pins_skill_level on public.pins (skill_id, level);

-- Seed skills (idempotent)
insert into public.skills (id, name, sort_order)
values
  ('planche', 'Planche', 1),
  ('front_lever', 'Front Lever', 2),
  ('handstand', 'Handstand', 3)
on conflict (id) do nothing;

-- Seed pins (idempotent) using frozen MVP trees + point system
-- Points v1:
-- tuck/wall_hs +20, adv_tuck/freestanding +40, straddle +80, full/hspu +140

insert into public.pins (skill_id, code, name, level, points, ai_threshold)
values
  ('planche', 'planche_tuck', 'Tuck', 1, 20, 70),
  ('planche', 'planche_adv_tuck', 'Advanced Tuck', 2, 40, 70),
  ('planche', 'planche_straddle', 'Straddle', 3, 80, 70),
  ('planche', 'planche_full', 'Full', 4, 140, 70),

  ('front_lever', 'front_lever_tuck', 'Tuck', 1, 20, 70),
  ('front_lever', 'front_lever_adv_tuck', 'Advanced Tuck', 2, 40, 70),
  ('front_lever', 'front_lever_straddle', 'Straddle', 3, 80, 70),
  ('front_lever', 'front_lever_full', 'Full', 4, 140, 70),

  ('handstand', 'handstand_wall_hs', 'Wall Handstand', 1, 20, 70),
  ('handstand', 'handstand_freestanding_hs', 'Freestanding Handstand', 2, 40, 70),
  ('handstand', 'handstand_hspu', 'Handstand Push-Up', 3, 140, 70)
on conflict (code) do nothing;

-- =========================
-- Videos (UGC)
-- =========================

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  skill_id text not null references public.skills(id),
  target_pin_code text references public.pins(code), -- user selects 1 target pin for verification flow
  storage_path text not null,                        -- Supabase Storage object key
  duration_seconds int not null check (duration_seconds between 1 and 30),
  status text not null check (status in ('active','hidden','removed')) default 'active',
  created_at timestamptz not null default now()
);

create index if not exists idx_videos_skill_created on public.videos (skill_id, created_at desc);
create index if not exists idx_videos_user_created on public.videos (user_id, created_at desc);

-- =========================
-- Pin claims + AI verification result (MVP)
-- =========================

create table if not exists public.pin_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  pin_id uuid not null references public.pins(id) on delete cascade,
  evidence_video_id uuid not null references public.videos(id) on delete cascade,
  status text not null check (status in ('pending','verified','rejected')) default 'pending',
  ai_score int check (ai_score between 0 and 100),
  ai_reasons jsonb,                     -- e.g. {"tags":["rom_low","form_breakdown"],"notes":"..."}
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, pin_id)
);

create index if not exists idx_pin_claims_user on public.pin_claims (user_id, created_at desc);
create index if not exists idx_pin_claims_status on public.pin_claims (status, created_at desc);

-- =========================
-- Likes + Saves (MVP social)
-- =========================

create table if not exists public.video_likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  video_id uuid not null references public.videos(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, video_id)
);

create table if not exists public.video_saves (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  video_id uuid not null references public.videos(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, video_id)
);

create index if not exists idx_video_likes_video on public.video_likes (video_id, created_at desc);
create index if not exists idx_video_saves_user on public.video_saves (user_id, created_at desc);

-- =========================
-- Reports (moderation MVP)
-- =========================

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('video','user')),
  target_id uuid not null,
  reason text,
  status text not null check (status in ('open','reviewed','actioned')) default 'open',
  created_at timestamptz not null default now()
);

create index if not exists idx_reports_status_created on public.reports (status, created_at desc);

-- =========================
-- Auto-create profile + rating when a new auth user is created
-- =========================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, created_at, updated_at)
  values (new.id, now(), now())
  on conflict (id) do nothing;

  insert into public.ratings_global (user_id, elo, updated_at)
  values (new.id, 1200, now())
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- =========================
-- RLS (minimal secure defaults)
-- NOTE: service role bypasses RLS; we keep sensitive updates server-side.
-- =========================

alter table public.profiles enable row level security;
alter table public.ratings_global enable row level security;
alter table public.skills enable row level security;
alter table public.pins enable row level security;
alter table public.videos enable row level security;
alter table public.pin_claims enable row level security;
alter table public.video_likes enable row level security;
alter table public.video_saves enable row level security;
alter table public.reports enable row level security;

-- PROFILES
drop policy if exists profiles_select on public.profiles;
create policy profiles_select
on public.profiles for select
using (auth.uid() is not null);

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self
on public.profiles for insert
with check (auth.uid() = id);

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- RATINGS (read-only from client)
drop policy if exists ratings_select on public.ratings_global;
create policy ratings_select
on public.ratings_global for select
using (auth.uid() is not null);

-- SKILLS/PINS (read-only from client)
drop policy if exists skills_select on public.skills;
create policy skills_select
on public.skills for select
using (auth.uid() is not null);

drop policy if exists pins_select on public.pins;
create policy pins_select
on public.pins for select
using (auth.uid() is not null);

-- VIDEOS
drop policy if exists videos_select on public.videos;
create policy videos_select
on public.videos for select
using (
  auth.uid() is not null
  and (status = 'active' or user_id = auth.uid())
);

drop policy if exists videos_insert_self on public.videos;
create policy videos_insert_self
on public.videos for insert
with check (auth.uid() = user_id);

drop policy if exists videos_update_self on public.videos;
create policy videos_update_self
on public.videos for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- PIN CLAIMS (client can create; server decides verified/rejected)
drop policy if exists pin_claims_select on public.pin_claims;
create policy pin_claims_select
on public.pin_claims for select
using (auth.uid() is not null and user_id = auth.uid());

drop policy if exists pin_claims_insert_self on public.pin_claims;
create policy pin_claims_insert_self
on public.pin_claims for insert
with check (auth.uid() = user_id);

-- LIKES
drop policy if exists video_likes_select on public.video_likes;
create policy video_likes_select
on public.video_likes for select
using (auth.uid() is not null);

drop policy if exists video_likes_insert_self on public.video_likes;
create policy video_likes_insert_self
on public.video_likes for insert
with check (auth.uid() = user_id);

drop policy if exists video_likes_delete_self on public.video_likes;
create policy video_likes_delete_self
on public.video_likes for delete
using (auth.uid() = user_id);

-- SAVES
drop policy if exists video_saves_select on public.video_saves;
create policy video_saves_select
on public.video_saves for select
using (auth.uid() is not null);

drop policy if exists video_saves_insert_self on public.video_saves;
create policy video_saves_insert_self
on public.video_saves for insert
with check (auth.uid() = user_id);

drop policy if exists video_saves_delete_self on public.video_saves;
create policy video_saves_delete_self
on public.video_saves for delete
using (auth.uid() = user_id);

-- REPORTS
drop policy if exists reports_insert on public.reports;
create policy reports_insert
on public.reports for insert
with check (auth.uid() = reporter_id);

drop policy if exists reports_select_own on public.reports;
create policy reports_select_own
on public.reports for select
using (auth.uid() = reporter_id);

