-- White Horse Pool Fines — Supabase Schema
-- Run this entire file in: Supabase Dashboard → SQL Editor → New Query

create extension if not exists "pgcrypto";

-- ── Core domain tables ───────────────────────────────────────────────────────
create table if not exists players (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz default now()
);

create table if not exists fine_types (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  cost        numeric(10,2) not null,
  created_at  timestamptz default now()
);

create table if not exists seasons (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  type        text not null default 'League',
  created_at  timestamptz default now()
);

create table if not exists matches (
  id          uuid primary key default gen_random_uuid(),
  date        date not null,
  season_id   uuid references seasons(id) on delete set null,
  opponent    text,
  submitted   boolean not null default false,
  created_at  timestamptz default now()
);

create table if not exists match_players (
  match_id    uuid not null references matches(id) on delete cascade,
  player_id   uuid not null references players(id) on delete cascade,
  primary key (match_id, player_id)
);

create table if not exists fines (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references matches(id) on delete cascade,
  player_id     uuid references players(id) on delete set null,
  fine_type_id  uuid references fine_types(id) on delete set null,
  player_name   text not null,
  fine_name     text not null,
  cost          numeric(10,2) not null,
  paid          boolean not null default false,
  created_at    timestamptz default now()
);

create table if not exists subs (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid not null references matches(id) on delete cascade,
  player_id   uuid references players(id) on delete set null,
  player_name text not null,
  amount      numeric(10,2) not null default 0.50,
  paid        boolean not null default false,
  created_at  timestamptz default now()
);

-- ── Auth-linked app profile table ────────────────────────────────────────────
create table if not exists app_users (
  id                     uuid primary key references auth.users(id) on delete cascade,
  email                  text,
  mobile                 text,
  preferred_auth_method  text not null default 'email',
  player_id              uuid references players(id) on delete set null,
  role                   text not null default 'member',
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint app_users_preferred_auth_method_check check (preferred_auth_method in ('email', 'whatsapp'))
);

create unique index if not exists app_users_email_unique_idx on app_users (lower(email)) where email is not null;
create unique index if not exists app_users_mobile_unique_idx on app_users (mobile) where mobile is not null;
create unique index if not exists app_users_player_unique_idx on app_users (player_id) where player_id is not null;

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_users_set_updated_at on app_users;
create trigger app_users_set_updated_at
before update on app_users
for each row execute function set_updated_at();

-- ── RLS ──────────────────────────────────────────────────────────────────────
alter table players enable row level security;
alter table fine_types enable row level security;
alter table seasons enable row level security;
alter table matches enable row level security;
alter table match_players enable row level security;
alter table fines enable row level security;
alter table subs enable row level security;
alter table app_users enable row level security;

drop policy if exists "authenticated full access players" on players;
create policy "authenticated full access players" on players
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access fine_types" on fine_types;
create policy "authenticated full access fine_types" on fine_types
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access seasons" on seasons;
create policy "authenticated full access seasons" on seasons
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access matches" on matches;
create policy "authenticated full access matches" on matches
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access match_players" on match_players;
create policy "authenticated full access match_players" on match_players
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access fines" on fines;
create policy "authenticated full access fines" on fines
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access subs" on subs;
create policy "authenticated full access subs" on subs
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "app_users self select" on app_users;
create policy "app_users self select" on app_users
  for select using (auth.uid() = id);

drop policy if exists "app_users self insert" on app_users;
create policy "app_users self insert" on app_users
  for insert with check (auth.uid() = id);

drop policy if exists "app_users self update" on app_users;
create policy "app_users self update" on app_users
  for update using (auth.uid() = id)
  with check (auth.uid() = id);

-- ── Optional migration notes for legacy player auth columns ──────────────────
-- If legacy auth columns exist on players (email/mobile/preferred_auth_method/auth_user_id),
-- they are intentionally ignored by app logic.
