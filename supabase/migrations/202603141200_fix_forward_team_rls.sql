-- Fix-forward migration: tighten RLS, consolidate player auth linkage, and add team ownership.
-- This migration is intentionally incremental/non-destructive for deployed environments.

create extension if not exists "pgcrypto";

-- 1) Ensure core multi-team tables exist (idempotent)
create table if not exists teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique,
  created_by uuid,
  created_at timestamptz not null default now()
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
create or replace function is_member_of_team(target_team_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from team_memberships tm
    join players p on p.id = tm.player_id
    where tm.team_id = target_team_id
      and tm.status = 'active'
      and p.user_id = auth.uid()
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
    join players p on p.id = tm.player_id
    where tm.team_id = target_team_id
      and tm.status = 'active'
      and tm.role in ('captain', 'admin')
      and p.user_id = auth.uid()
  );
$$;

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
alter table app_users enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['players','fine_types','seasons','matches','match_players','fines','subs','teams','team_memberships','team_invites']
  loop
    execute format('drop policy if exists "allow all" on %I', t);
    execute format('drop policy if exists "authenticated read/write" on %I', t);
  end loop;

  execute 'drop policy if exists "own profile" on players';
  execute 'drop policy if exists "team players read" on players';
  execute 'drop policy if exists "team players write" on players';
  execute 'drop policy if exists "team scoped read" on fine_types';
  execute 'drop policy if exists "team scoped write" on fine_types';
  execute 'drop policy if exists "team scoped read" on seasons';
  execute 'drop policy if exists "team scoped write" on seasons';
  execute 'drop policy if exists "team scoped read" on matches';
  execute 'drop policy if exists "team scoped write" on matches';
  execute 'drop policy if exists "team scoped read" on match_players';
  execute 'drop policy if exists "team scoped write" on match_players';
  execute 'drop policy if exists "team scoped read" on fines';
  execute 'drop policy if exists "team scoped write" on fines';
  execute 'drop policy if exists "team scoped read" on subs';
  execute 'drop policy if exists "team scoped write" on subs';
  execute 'drop policy if exists "team scoped read" on teams';
  execute 'drop policy if exists "team scoped write" on teams';
  execute 'drop policy if exists "team scoped read" on team_memberships';
  execute 'drop policy if exists "team scoped write" on team_memberships';
  execute 'drop policy if exists "team scoped read" on team_invites';
  execute 'drop policy if exists "team scoped write" on team_invites';
  execute 'drop policy if exists "app_users self" on app_users';
end $$;

-- players: allow user to read own linked player row + players in their teams. Writes are self-row only.
create policy "own profile" on players
for select to authenticated
using (
  user_id = auth.uid()
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  or exists (
    select 1
    from team_memberships mine
    join players me on me.id = mine.player_id
    join team_memberships theirs on theirs.team_id = mine.team_id and theirs.player_id = players.id
    where me.user_id = auth.uid()
      and mine.status = 'active'
      and theirs.status = 'active'
  )
);

create policy "team players write" on players
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- team-scoped tables
create policy "team scoped read" on fine_types for select to authenticated using (is_member_of_team(team_id));
create policy "team scoped write" on fine_types for all to authenticated using (is_member_of_team(team_id)) with check (is_member_of_team(team_id));

create policy "team scoped read" on seasons for select to authenticated using (is_member_of_team(team_id));
create policy "team scoped write" on seasons for all to authenticated using (is_member_of_team(team_id)) with check (is_member_of_team(team_id));

create policy "team scoped read" on matches for select to authenticated using (is_member_of_team(team_id));
create policy "team scoped write" on matches for all to authenticated using (is_member_of_team(team_id)) with check (is_member_of_team(team_id));

create policy "team scoped read" on match_players for select to authenticated
using (exists (select 1 from matches m where m.id = match_players.match_id and is_member_of_team(m.team_id)));
create policy "team scoped write" on match_players for all to authenticated
using (exists (select 1 from matches m where m.id = match_players.match_id and is_member_of_team(m.team_id)))
with check (exists (select 1 from matches m where m.id = match_players.match_id and is_member_of_team(m.team_id)));

create policy "team scoped read" on fines for select to authenticated
using (exists (select 1 from matches m where m.id = fines.match_id and is_member_of_team(m.team_id)));
create policy "team scoped write" on fines for all to authenticated
using (exists (select 1 from matches m where m.id = fines.match_id and is_member_of_team(m.team_id)))
with check (exists (select 1 from matches m where m.id = fines.match_id and is_member_of_team(m.team_id)));

create policy "team scoped read" on subs for select to authenticated
using (exists (select 1 from matches m where m.id = subs.match_id and is_member_of_team(m.team_id)));
create policy "team scoped write" on subs for all to authenticated
using (exists (select 1 from matches m where m.id = subs.match_id and is_member_of_team(m.team_id)))
with check (exists (select 1 from matches m where m.id = subs.match_id and is_member_of_team(m.team_id)));

create policy "team scoped read" on teams for select to authenticated using (is_member_of_team(id));
create policy "team scoped write" on teams for update to authenticated using (is_admin_of_team(id)) with check (is_admin_of_team(id));
create policy "team create" on teams for insert to authenticated with check (auth.uid() is not null);

create policy "team scoped read" on team_memberships for select to authenticated using (is_member_of_team(team_id));
create policy "team scoped write" on team_memberships for all to authenticated using (is_admin_of_team(team_id)) with check (is_admin_of_team(team_id));

create policy "team scoped read" on team_invites for select to authenticated using (is_member_of_team(team_id));
create policy "team scoped write" on team_invites for all to authenticated using (is_member_of_team(team_id)) with check (is_member_of_team(team_id));

create policy "app_users self" on app_users for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

