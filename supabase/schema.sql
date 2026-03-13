-- White Horse Pool Fines — Supabase Schema
-- Run this entire file in: Supabase Dashboard → SQL Editor → New Query

-- Enable UUID extension
create extension if not exists "pgcrypto";

-- ── Players ──────────────────────────────────────────────────────────────────
create table if not exists players (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz default now()
);

-- ── Fine Types ────────────────────────────────────────────────────────────────
create table if not exists fine_types (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  cost        numeric(10,2) not null,
  created_at  timestamptz default now()
);

-- ── Seasons ───────────────────────────────────────────────────────────────────
create table if not exists seasons (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  type        text not null default 'League', -- 'League' | 'Cup'
  created_at  timestamptz default now()
);

-- ── Matches ───────────────────────────────────────────────────────────────────
create table if not exists matches (
  id          uuid primary key default gen_random_uuid(),
  date        date not null,
  season_id   uuid references seasons(id) on delete set null,
  opponent    text,
  submitted   boolean not null default false,
  created_at  timestamptz default now()
);

-- ── Match Players (who played in each match) ──────────────────────────────────
create table if not exists match_players (
  match_id    uuid not null references matches(id) on delete cascade,
  player_id   uuid not null references players(id) on delete cascade,
  primary key (match_id, player_id)
);

-- ── Fines ─────────────────────────────────────────────────────────────────────
create table if not exists fines (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references matches(id) on delete cascade,
  player_id     uuid references players(id) on delete set null,
  fine_type_id  uuid references fine_types(id) on delete set null,
  player_name   text not null,  -- denormalised so history survives player rename/delete
  fine_name     text not null,  -- denormalised so history survives fine type rename/delete
  cost          numeric(10,2) not null,
  paid          boolean not null default false,
  created_at    timestamptz default now()
);

-- ── Subs ──────────────────────────────────────────────────────────────────────
create table if not exists subs (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid not null references matches(id) on delete cascade,
  player_id   uuid references players(id) on delete set null,
  player_name text not null,  -- denormalised
  amount      numeric(10,2) not null default 0.50,
  paid        boolean not null default false,
  created_at  timestamptz default now()
);

-- ── Row Level Security ────────────────────────────────────────────────────────
-- The app uses the anon key, so we need to allow full access.
-- For a private club app this is fine. If you want auth in future,
-- replace these policies with user-scoped ones.

alter table players      enable row level security;
alter table fine_types   enable row level security;
alter table seasons      enable row level security;
alter table matches      enable row level security;
alter table match_players enable row level security;
alter table fines        enable row level security;
alter table subs         enable row level security;

-- Allow all operations for anon (unauthenticated) role
create policy "allow all" on players      for all using (true) with check (true);
create policy "allow all" on fine_types   for all using (true) with check (true);
create policy "allow all" on seasons      for all using (true) with check (true);
create policy "allow all" on matches      for all using (true) with check (true);
create policy "allow all" on match_players for all using (true) with check (true);
create policy "allow all" on fines        for all using (true) with check (true);
create policy "allow all" on subs         for all using (true) with check (true);
