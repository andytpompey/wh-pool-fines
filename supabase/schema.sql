-- Fix-forward migration: tighten RLS, consolidate player auth linkage, and add team ownership.
-- This migration is intentionally incremental/non-destructive for deployed environments.

create extension if not exists "pgcrypto";

-- ── Core domain tables ───────────────────────────────────────────────────────
create table if not exists players (
  id                     uuid primary key default gen_random_uuid(),
  name                   text not null,
  display_name           text not null,
  email                  text not null,
  mobile                 text unique,
  preferred_auth_method  text not null default 'email' check (preferred_auth_method in ('email', 'whatsapp')),
  auth_user_id           uuid,
  user_id                uuid,
  receive_team_notifications boolean not null default true,
  created_at             timestamptz default now(),
  constraint players_auth_contact_check check (email is not null)
);

create table if not exists team_memberships (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  role text not null check (role in ('captain', 'admin', 'member')),
  status text not null default 'active' check (status in ('active', 'invited', 'removed')),
  joined_at timestamptz not null default now(),
  unique (team_id, player_id)
);

create table if not exists team_invites (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams(id) on delete cascade,
  email text not null,
  player_id uuid references players(id) on delete set null,
  invited_by_player_id uuid references players(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'expired', 'cancelled')),
  token text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

-- 2) Consolidate auth linkage to players.user_id (keep auth_user_id for compatibility)
alter table players add column if not exists user_id uuid;
alter table players add column if not exists auth_user_id uuid;
update players
set user_id = coalesce(user_id, auth_user_id)
where user_id is null and auth_user_id is not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'players_user_id_fkey'
      and conrelid = 'public.players'::regclass
  ) then
    alter table players
      add constraint players_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete set null;
  end if;
end $$;

create unique index if not exists players_user_id_unique_idx on players (user_id) where user_id is not null;
create unique index if not exists players_email_unique_idx on players (lower(email)) where email is not null;

comment on column players.auth_user_id is 'DEPRECATED compatibility column. New code should only use players.user_id.';

-- 3) Keep app_users for compatibility only; deprecate overlapping identity fields.
create table if not exists app_users (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table app_users is 'Compatibility metadata table only. Player identity and role ownership live in players/team_memberships.';
comment on column app_users.id is 'Maps 1:1 to auth.users.id. Do not treat this table as canonical player identity.';

-- 4) Add team ownership columns to core tables + backfill safely
alter table fine_types add column if not exists team_id uuid references teams(id) on delete cascade;
alter table seasons add column if not exists team_id uuid references teams(id) on delete cascade;
alter table matches add column if not exists team_id uuid references teams(id) on delete cascade;

create index if not exists fine_types_team_id_idx on fine_types(team_id);
create index if not exists seasons_team_id_idx on seasons(team_id);
create index if not exists matches_team_id_idx on matches(team_id);
create index if not exists team_memberships_team_id_idx on team_memberships(team_id);
create index if not exists team_memberships_player_id_idx on team_memberships(player_id);
create index if not exists team_invites_team_id_idx on team_invites(team_id);
create index if not exists team_invites_email_idx on team_invites(lower(email));

-- Create one fallback team if needed and backfill legacy rows to that team.
do $$
declare
  fallback_team_id uuid;
begin
  select id into fallback_team_id from teams order by created_at asc limit 1;

  if fallback_team_id is null then
    insert into teams (name, join_code)
    values ('White Horse', encode(gen_random_bytes(5), 'hex'))
    returning id into fallback_team_id;
  end if;

  update fine_types set team_id = fallback_team_id where team_id is null;
  update seasons set team_id = fallback_team_id where team_id is null;
  update matches set team_id = fallback_team_id where team_id is null;

  insert into team_memberships (team_id, player_id, role, status)
  select fallback_team_id, p.id, 'member', 'active'
  from players p
  where not exists (
    select 1 from team_memberships tm where tm.team_id = fallback_team_id and tm.player_id = p.id
  );
end $$;

-- Keep nullable for this step to avoid breaking legacy writes; TODO tighten to NOT NULL after all writes include team_id.
comment on column fine_types.team_id is 'TODO: make NOT NULL once all write paths provide team_id.';
comment on column seasons.team_id is 'TODO: make NOT NULL once all write paths provide team_id.';
comment on column matches.team_id is 'TODO: make NOT NULL once all write paths provide team_id.';

-- 5) Prevent duplicate pending invites per team/email, case-insensitive
create unique index if not exists team_invites_pending_unique_idx
  on team_invites (team_id, lower(email))
  where status = 'pending';

-- 6) Clarify name/display_name and stop fake email generation in steady state
alter table players add column if not exists display_name text;
update players set display_name = coalesce(display_name, name) where display_name is null;
update players set name = coalesce(name, display_name) where name is null;

comment on column players.display_name is 'Canonical player profile name.';
comment on column players.name is 'Legacy compatibility alias for display_name.';

create or replace function sync_player_name_columns()
returns trigger
language plpgsql
as $$
begin
  if new.display_name is null and new.name is not null then
    new.display_name := new.name;
  end if;
  if new.name is null and new.display_name is not null then
    new.name := new.display_name;
  end if;
  return new;
end;
$$;

drop trigger if exists players_sync_name_columns on players;
create trigger players_sync_name_columns
before insert or update on players
for each row execute function sync_player_name_columns();

-- Avoid forcing NOT NULL immediately in case legacy rows still have placeholders/missing values.
-- New writes are validated in app/server code.

-- 7) Tighten RLS from permissive policies to team-aware auth checks.
create or replace function current_player_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from players p
  where p.user_id = auth.uid()
  limit 1;
$$;

create or replace function is_member_of_team(target_team_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from team_memberships tm
    where tm.team_id = target_team_id
      and tm.status = 'active'
      and tm.player_id = current_player_id()
  );
$$;

create or replace function is_admin_of_team(target_team_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from team_memberships tm
    where tm.team_id = target_team_id
      and tm.status = 'active'
      and tm.role in ('captain', 'admin')
      and tm.player_id = current_player_id()
  );
$$;

alter table players enable row level security;
alter table fine_types enable row level security;
alter table seasons enable row level security;
alter table matches enable row level security;
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


-- Multi-team domain tables
create table if not exists teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text unique not null,
  created_by uuid null references players(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists team_memberships (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  role text not null check (role in ('captain','admin','member')),
  status text not null default 'active' check (status in ('active','invited','removed')),
  joined_at timestamptz not null default now(),
  unique(team_id, player_id)
);

create table if not exists team_invites (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references teams(id) on delete cascade,
  email text not null,
  player_id uuid null references players(id) on delete set null,
  invited_by_player_id uuid null references players(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','accepted','expired','cancelled')),
  token text unique not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz null
);

alter table teams enable row level security;
alter table team_memberships enable row level security;
alter table team_invites enable row level security;

create policy "allow all" on teams            for all using (true) with check (true);
create policy "allow all" on team_memberships for all using (true) with check (true);
create policy "allow all" on team_invites     for all using (true) with check (true);


-- Add auth columns for existing projects running earlier schema versions
alter table players add column if not exists email text;
alter table players add column if not exists mobile text;
alter table players add column if not exists preferred_auth_method text not null default 'email';
alter table players add column if not exists auth_user_id uuid;
alter table players add column if not exists display_name text;
alter table players add column if not exists user_id uuid;
alter table players add column if not exists receive_team_notifications boolean not null default true;

update players set display_name = coalesce(display_name, name) where display_name is null;
update players set user_id = auth_user_id where user_id is null and auth_user_id is not null;
update players set email = concat('player-', id::text, '@placeholder.local') where email is null or btrim(email) = '';

alter table players alter column display_name set not null;
alter table players alter column email set not null;

create unique index if not exists players_email_unique_idx on players (lower(email)) where email is not null;
create unique index if not exists players_mobile_unique_idx on players (mobile) where mobile is not null;
create unique index if not exists players_user_id_unique_idx on players (user_id) where user_id is not null;
create index if not exists players_display_name_idx on players (display_name);

create index if not exists teams_join_code_idx on teams (join_code);
create index if not exists teams_created_by_idx on teams (created_by);
create index if not exists team_memberships_team_id_idx on team_memberships (team_id);
create index if not exists team_memberships_player_id_idx on team_memberships (player_id);
create index if not exists team_invites_team_id_idx on team_invites (team_id);
create index if not exists team_invites_player_id_idx on team_invites (player_id);
create index if not exists team_invites_email_idx on team_invites (lower(email));

create or replace function sync_player_profile_columns()
returns trigger
language plpgsql
as $$
begin
  if new.display_name is null or btrim(new.display_name) = '' then
    new.display_name = coalesce(new.name, 'Unknown Player');
  end if;

  if new.name is null or btrim(new.name) = '' then
    new.name = new.display_name;
  end if;

  if new.user_id is null and new.auth_user_id is not null then
    new.user_id = new.auth_user_id;
  end if;

  if new.auth_user_id is null and new.user_id is not null then
    new.auth_user_id = new.user_id;
  end if;

  if new.email is null or btrim(new.email) = '' then
    new.email = concat('player-', coalesce(new.id, gen_random_uuid())::text, '@placeholder.local');
  end if;

  return new;
end;
$$;

drop trigger if exists players_sync_profile_columns on players;
create trigger players_sync_profile_columns
before insert or update on players
for each row execute function sync_player_profile_columns();

create or replace function generate_team_join_code()
returns text
language plpgsql
as $$
declare
  generated_code text;
  attempt_count integer := 0;
begin
  loop
    attempt_count := attempt_count + 1;
    generated_code := upper(encode(gen_random_bytes(4), 'hex'));

    exit when not exists (
      select 1 from teams t where t.join_code = generated_code
    );

    if attempt_count > 10 then
      raise exception 'Unable to generate a unique team join code';
    end if;
  end loop;

  return generated_code;
end;
$$;

create or replace function set_team_join_code()
returns trigger
language plpgsql
as $$
begin
  if new.join_code is null or btrim(new.join_code) = '' then
    new.join_code = generate_team_join_code();
  else
    new.join_code = upper(btrim(new.join_code));
  end if;

  return new;
end;
$$;

drop trigger if exists teams_set_join_code on teams;
create trigger teams_set_join_code
before insert or update of join_code on teams
for each row execute function set_team_join_code();

