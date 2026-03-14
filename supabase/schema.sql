-- White Horse Pool Fines — Supabase Schema
-- Run this entire file in: Supabase Dashboard → SQL Editor → New Query

create extension if not exists "pgcrypto";

-- ── Core domain tables ───────────────────────────────────────────────────────
create table if not exists teams (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  join_code   text not null unique,
  created_by  uuid,
  created_at  timestamptz not null default now()
);

create table if not exists players (
  id                          uuid primary key default gen_random_uuid(),
  display_name                text not null,
  name                        text,
  email                       text not null,
  mobile                      text unique,
  preferred_auth_method       text not null default 'email' check (preferred_auth_method in ('email', 'whatsapp')),
  user_id                     uuid unique,
  receive_team_notifications  boolean not null default true,
  created_at                  timestamptz not null default now()
);

comment on column players.display_name is 'Canonical player profile name used across teams.';
comment on column players.name is 'Legacy compatibility alias for display_name; do not use for new writes.';

create table if not exists fine_types (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid references teams(id) on delete cascade,
  name        text not null,
  cost        numeric(10,2) not null,
  created_at  timestamptz default now()
);

create table if not exists seasons (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid references teams(id) on delete cascade,
  name        text not null,
  type        text not null default 'League',
  created_at  timestamptz default now()
);

create table if not exists matches (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid references teams(id) on delete cascade,
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

create table if not exists team_memberships (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references teams(id) on delete cascade,
  player_id  uuid not null references players(id) on delete cascade,
  role       text not null check (role in ('captain', 'admin', 'member')),
  status     text not null default 'active' check (status in ('active', 'invited', 'removed')),
  joined_at  timestamptz not null default now(),
  unique (team_id, player_id)
);

create table if not exists team_invites (
  id                    uuid primary key default gen_random_uuid(),
  team_id               uuid not null references teams(id) on delete cascade,
  email                 text not null,
  player_id             uuid references players(id) on delete set null,
  invited_by_player_id  uuid references players(id) on delete set null,
  status                text not null default 'pending' check (status in ('pending', 'accepted', 'expired', 'cancelled')),
  token                 text not null unique,
  created_at            timestamptz not null default now(),
  expires_at            timestamptz
);

-- ── Legacy/schema-evolution compatibility ───────────────────────────────────
alter table players add column if not exists display_name text;
alter table players add column if not exists name text;
alter table players add column if not exists email text;
alter table players add column if not exists mobile text;
alter table players add column if not exists preferred_auth_method text not null default 'email';
alter table players add column if not exists user_id uuid;
alter table players add column if not exists receive_team_notifications boolean not null default true;

-- Consolidate historical auth_user_id into user_id
alter table players add column if not exists auth_user_id uuid;
update players set user_id = coalesce(user_id, auth_user_id) where user_id is null and auth_user_id is not null;

-- Promote display_name as canonical and mirror to legacy name
update players set display_name = coalesce(display_name, name) where display_name is null;
update players set name = coalesce(name, display_name) where name is null;

alter table players alter column display_name set not null;
alter table players alter column email set not null;

create or replace function sync_player_name_columns()
returns trigger
language plpgsql
as $$
begin
  if new.display_name is null and new.name is not null then
    new.display_name = new.name;
  end if;
  if new.name is null and new.display_name is not null then
    new.name = new.display_name;
  end if;
  return new;
end;
$$;

drop trigger if exists players_sync_name_columns on players;
create trigger players_sync_name_columns
before insert or update on players
for each row execute function sync_player_name_columns();

alter table players drop constraint if exists players_preferred_auth_method_check;
alter table players add constraint players_preferred_auth_method_check
  check (preferred_auth_method in ('email', 'whatsapp'));

alter table fine_types add column if not exists team_id uuid references teams(id) on delete cascade;
alter table seasons add column if not exists team_id uuid references teams(id) on delete cascade;
alter table matches add column if not exists team_id uuid references teams(id) on delete cascade;

-- app_users overlap removed; identity linkage is now players.user_id
alter table if exists app_users disable row level security;
drop table if exists app_users cascade;

alter table players drop column if exists auth_user_id;

-- ── Indexes ──────────────────────────────────────────────────────────────────
create unique index if not exists teams_join_code_unique_idx on teams (join_code);
create unique index if not exists players_email_unique_idx on players (lower(email));
create unique index if not exists players_mobile_unique_idx on players (mobile) where mobile is not null;
create unique index if not exists players_user_id_unique_idx on players (user_id) where user_id is not null;

create index if not exists fine_types_team_id_idx on fine_types (team_id);
create index if not exists seasons_team_id_idx on seasons (team_id);
create index if not exists matches_team_id_idx on matches (team_id);
create index if not exists team_memberships_team_id_idx on team_memberships (team_id);
create index if not exists team_memberships_player_id_idx on team_memberships (player_id);
create index if not exists team_invites_team_id_idx on team_invites (team_id);
create index if not exists team_invites_email_idx on team_invites (lower(email));

-- Only one pending invite for a given team/email pair
create unique index if not exists team_invites_pending_unique_idx
  on team_invites (team_id, lower(email))
  where status = 'pending';

-- ── RLS ──────────────────────────────────────────────────────────────────────
alter table players enable row level security;
alter table fine_types enable row level security;
alter table seasons enable row level security;
alter table matches enable row level security;
alter table match_players enable row level security;
alter table fines enable row level security;
alter table subs enable row level security;
alter table teams enable row level security;
alter table team_memberships enable row level security;
alter table team_invites enable row level security;

-- Remove permissive policies from previous versions
DO $$
DECLARE
  p record;
BEGIN
  FOR p IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public' AND policyname = 'allow all'
  LOOP
    EXECUTE format('drop policy if exists %I on %I', p.policyname, p.tablename);
  END LOOP;
END $$;

-- Temporary safe policy set: authenticated users only
drop policy if exists "authenticated read/write" on players;
drop policy if exists "authenticated read/write" on fine_types;
drop policy if exists "authenticated read/write" on seasons;
drop policy if exists "authenticated read/write" on matches;
drop policy if exists "authenticated read/write" on match_players;
drop policy if exists "authenticated read/write" on fines;
drop policy if exists "authenticated read/write" on subs;
drop policy if exists "authenticated read/write" on teams;
drop policy if exists "authenticated read/write" on team_memberships;
drop policy if exists "authenticated read/write" on team_invites;

create policy "authenticated read/write" on players for all to authenticated using (true) with check (true);
create policy "authenticated read/write" on fine_types for all to authenticated using (true) with check (true);
create policy "authenticated read/write" on seasons for all to authenticated using (true) with check (true);
create policy "authenticated read/write" on matches for all to authenticated using (true) with check (true);
create policy "authenticated read/write" on match_players for all to authenticated using (true) with check (true);
create policy "authenticated read/write" on fines for all to authenticated using (true) with check (true);
create policy "authenticated read/write" on subs for all to authenticated using (true) with check (true);
create policy "authenticated read/write" on teams for all to authenticated using (true) with check (true);
create policy "authenticated read/write" on team_memberships for all to authenticated using (true) with check (true);
create policy "authenticated read/write" on team_invites for all to authenticated using (true) with check (true);
